//
//  ConnectionHandler+Read.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/11/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

extension ConnectionHandler : RequestSocketReadDelegate {

    func receivedHeader(data receivedData: Data) {

        // Is this a malformed request?
        guard data.appendHeaderData(receivedData) else {
            report(.invalidHeaderDataReceived(receivedData))
            return
        }

        headerLines = headerLines + 1

        // Are we done reading?
        guard data.headerComplete else {

            // Could this be a DOS attack?
            guard headerLines <  100 else {
                overflowDetected()
                return
            }

            socket.read(.Header)
            return
        }

        // Do we have a method?
        let method = data.method
        guard method != .Unknown else {
            report(.noHTTPMethod)
            return
        }

        // Do we have a URI?
        guard let uriString = data.url?.relativeString else {
            report(.noURI)
            return
        }

        let possibleTransferEncoding = data.headerField("Transfer-Encoding")
        let possibleContentLength = data.headerField("Content-Length")

        // Are we expecting a body?
        var expectsBody = (.POST == method || .PUT == method)
        if let delegateExpectsBody = bodyParsingDelegate?.shouldAcceptBody(request: self, method: method, path: uriString) {
            expectsBody = delegateExpectsBody
        }

        if expectsBody {

            if let transferEncoding = possibleTransferEncoding, transferEncoding.caseInsensitiveCompare("Chunked") != .orderedSame {
                // 1. Chunked body
                contentLength = -1
            } else {
                // 2. Not Chunked body
                guard possibleContentLength != nil else {
                    report(.missingContentLength)
                    return
                }

                guard let givenContentLengthString = possibleContentLength,
                    let givenContentLength = Int(givenContentLengthString) else {
                        report(.invalidContentLength)
                        return
                }

                contentLength = givenContentLength
            }

            contentLengthReceived = 0;

            bodyParsingDelegate?.willReceiveBody(request: self, bodySize: contentLength)

            // Does the body have length?
            guard contentLength <= 0 else {

                if contentLength == -1 {
                    socket.read(.ChunkSize)
                } else {
                    let remainingBytes = (contentLength < 1024 * 512) ? UInt(contentLength) : UInt(1024 * 512)
                    socket.read(.Body(bytesToRead: remainingBytes))
                }
                return
            }

            bodyParsingDelegate?.didFinishReceivingBody(request: self)

        } else {

            if possibleContentLength != nil {

                // We received a Content-Length header for a method not expecting an upload.
                // This better be zero...
                guard let givenContentLengthString = possibleContentLength,
                    let givenContentLength = Int(givenContentLengthString),
                    givenContentLength == 0 else {
                        report(.unexpectedContentLength)
                        return
                }
            }

            contentLength = 0
            contentLengthReceived = 0
        }

        report(.success)
    }

    func receivedChunkSize(data: Data) {

        let sizeLine = String(data: data, encoding: String.Encoding.utf8)

        chunkSize = UInt64(strtoull(sizeLine, nil, 16))
        chunkSizeReceived = 0

        if chunkSize > 0 {
            let remainingBytes = (contentLength < 1024 * 512) ? UInt(contentLength) : UInt(1024 * 512)
            socket.read(.ChunkData(bytesToRead: remainingBytes))
        } else {
            // This is the "0" (zero) line,
            // which is to be followed by optional footers (just like headers) and finally a blank line.
            socket.read(.ChunkFooter)
        }
    }

    func receivedChunkData(data: Data) {

        // We just read part of the actual data.
        contentLengthReceived = contentLengthReceived + data.count
        chunkSizeReceived = chunkSizeReceived + UInt64(data.count)

        if let assignedBodyParsingDelegate = bodyParsingDelegate {
            assignedBodyParsingDelegate.didReceiveBodyChunk(request: self, data: data)
        } else {
            self.data.appendHeaderData(data)
        }

        let bytesLeft = chunkSize - chunkSizeReceived
        if bytesLeft > 0 {
            let remainingBytes = bytesLeft < 1024 * 512 ? UInt(bytesLeft) : UInt(1024 * 512)
            socket.read(.Body(bytesToRead: remainingBytes))
        } else {
            // We've read in all the data for this chunk.
            // The data is followed by a CRLF, which we need to read (and basically ignore)
            socket.read(.ChunkTrailer)
        }
    }

    func receivedChunkTrailer(data: Data) {

        // This should be the CRLF following the data.
        // Just ensure it's a CRLF.
        guard data == GCDAsyncSocket.crlfData() else {
            report(.missingChunkTrailer)
            return
        }

        socket.read(.ChunkSize)
    }

    func receivedChunkFooter(data: Data) {

        headerLines = headerLines + 1
        guard headerLines < 200 else {
            overflowDetected()
            return
        }

        guard data.count <= 2 else {
            // In the future we may want to append these to the request.
            // For now we ignore, and continue reading the footers, waiting for the final blank line.
            socket.read(.ChunkFooter)
            return
        }

        bodyParsingDelegate?.didFinishReceivingBody(request: self)
        report(.success)
    }

    func receivedBody(data: Data) {

        contentLengthReceived = contentLengthReceived + data.count
        bodyParsingDelegate?.didReceiveBodyChunk(request: self, data: data)

        guard contentLengthReceived >= contentLength else {
            // We're not done reading the post body yet...
            let bytesLeft = contentLength - contentLengthReceived
            let bytesToRead = bytesLeft < 1024 * 512 ? UInt(bytesLeft) : UInt(1024 * 512)

            socket.read(.Body(bytesToRead: bytesToRead))
            return
        }
        
        bodyParsingDelegate?.didFinishReceivingBody(request: self)
        report(.success)
    }
    
    private func overflowDetected() {
        socket.stop()
        report(.headerLineCountOverflow)
    }
    
    private func report(_ status: ConnectionHandler.Status) {
        self.status = status
        delegate!.reply(request: data, fromHandler: self)
    }
}
