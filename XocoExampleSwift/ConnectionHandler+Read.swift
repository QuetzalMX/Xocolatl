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
        guard request.appendHeaderData(receivedData) else {
            requestResponse(toStatus: .invalidHeaderDataReceived(receivedData))
            return
        }

        request.headerLines = request.headerLines + 1

        // Are we done reading?
        guard request.headerComplete else {

            // Could this be a DOS attack?
            guard request.headerLines <  100 else {
                overflowDetected()
                return
            }

            read(.Header)
            return
        }

        // Do we have a method?
        let method = request.method
        guard method != .Unknown else {
            requestResponse(toStatus: .noHTTPMethod)
            return
        }

        // Do we have a URI?
        guard let uriString = request.url?.relativeString else {
            requestResponse(toStatus: .noURI)
            return
        }

        let possibleTransferEncoding = request.headerField("Transfer-Encoding")
        let possibleContentLength = request.headerField("Content-Length")

        // Are we expecting a body?
        var expectsBody = (.POST == method || .PUT == method)
        if let delegateExpectsBody = bodyParsingDelegate?.shouldAcceptBody(request: self, method: method, path: uriString) {
            expectsBody = delegateExpectsBody
        }

        if expectsBody {

            if let transferEncoding = possibleTransferEncoding, transferEncoding.caseInsensitiveCompare("Chunked") != .orderedSame {
                // 1. Chunked body
                request.contentLength = -1
            } else {
                // 2. Not Chunked body
                guard possibleContentLength != nil else {
                    requestResponse(toStatus: .missingContentLength)
                    return
                }

                guard let givenContentLengthString = possibleContentLength,
                    let givenContentLength = Int(givenContentLengthString) else {
                        requestResponse(toStatus: .invalidContentLength)
                        return
                }

                request.contentLength = givenContentLength
            }

            request.contentLengthReceived = 0;

            bodyParsingDelegate?.willReceiveBody(request: self, bodySize: request.contentLength)

            // Does the body have length?
            guard request.contentLength <= 0 else {

                if request.contentLength == -1 {
                    read(.ChunkSize)
                } else {
                    let remainingBytes = (request.contentLength < 1024 * 512) ? UInt(request.contentLength) : UInt(1024 * 512)
                    read(.Body(bytesToRead: remainingBytes))
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
                        requestResponse(toStatus: .unexpectedContentLength)
                        return
                }
            }

            request.contentLength = 0
            request.contentLengthReceived = 0
        }

        requestResponse(toStatus: .success)
    }

    func receivedChunkSize(data: Data) {

        let sizeLine = String(data: data, encoding: String.Encoding.utf8)

        request.chunkSize = UInt64(strtoull(sizeLine, nil, 16))
        request.chunkSizeReceived = 0

        if request.chunkSize > 0 {
            let remainingBytes = (request.contentLength < 1024 * 512) ? UInt(request.contentLength) : UInt(1024 * 512)
            read(.ChunkData(bytesToRead: remainingBytes))
        } else {
            // This is the "0" (zero) line,
            // which is to be followed by optional footers (just like headers) and finally a blank line.
            read(.ChunkFooter)
        }
    }

    func receivedChunkData(data: Data) {

        // We just read part of the actual data.
        request.contentLengthReceived = request.contentLengthReceived + data.count
        request.chunkSizeReceived = request.chunkSizeReceived + UInt64(data.count)

        appendBodyDataIfNecessary(data)

        let bytesLeft = request.chunkSize - request.chunkSizeReceived
        if bytesLeft > 0 {
            let remainingBytes = bytesLeft < 1024 * 512 ? UInt(bytesLeft) : UInt(1024 * 512)
            read(.Body(bytesToRead: remainingBytes))
        } else {
            // We've read in all the data for this chunk.
            // The data is followed by a CRLF, which we need to read (and basically ignore)
            read(.ChunkTrailer)
        }
    }

    func receivedChunkTrailer(data: Data) {

        // This should be the CRLF following the data.
        // Just ensure it's a CRLF.
        guard data == GCDAsyncSocket.crlfData() else {
            requestResponse(toStatus: .missingChunkTrailer)
            return
        }

        read(.ChunkSize)
    }

    func receivedChunkFooter(data: Data) {

        request.headerLines = request.headerLines + 1
        guard request.headerLines < 200 else {
            overflowDetected()
            return
        }

        guard data.count <= 2 else {
            // In the future we may want to append these to the request.
            // For now we ignore, and continue reading the footers, waiting for the final blank line.
            read(.ChunkFooter)
            return
        }

        bodyParsingDelegate?.didFinishReceivingBody(request: self)
        requestResponse(toStatus: .success)
    }

    func receivedBody(data: Data) {

        request.contentLengthReceived = request.contentLengthReceived + data.count

        appendBodyDataIfNecessary(data)

        guard request.contentLengthReceived >= request.contentLength else {
            // We're not done reading the post body yet...
            let bytesLeft = request.contentLength - request.contentLengthReceived
            let bytesToRead = bytesLeft < 1024 * 512 ? UInt(bytesLeft) : UInt(1024 * 512)

            read(.Body(bytesToRead: bytesToRead))
            return
        }
        
        bodyParsingDelegate?.didFinishReceivingBody(request: self)
        requestResponse(toStatus: .success)
    }
}

extension ConnectionHandler {

    fileprivate func overflowDetected() {
        closeConnection()
        requestResponse(toStatus: .headerLineCountOverflow)
    }

    fileprivate func requestResponse(toStatus status: Request.Status) {
        request.status = status
        let delegateResponse = delegate!.reply(toRequest: request)
        respond(with: delegateResponse)
        NotificationCenter.default.post(name: Notification.Name("Responded"), object: [request, delegateResponse])
    }

    fileprivate func appendBodyDataIfNecessary(_ data: Data) {

        if let assignedBodyParsingDelegate = bodyParsingDelegate {
            assignedBodyParsingDelegate.didReceiveBodyChunk(request: self, data: data)
        } else {
            self.request.appendBodyData(data)
        }
    }
}
