//
//  Request.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/7/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

// MARK: Protocols
/// Once a request is either completed or failed to be parsed, it is forwarded to our delegate.
protocol RequestCompletionDelegate {
    func reply(request: Request, inSocket: RequestSocket, status: Request.Status)
}

/// Optionally accept the request's body and save it as necessary.
protocol RequestBodyParsingDelegate {
    func shouldAcceptBody(request: Request, method: Method, path: String) -> Bool
    func willReceiveBody(request: Request, bodySize: Int)
    func didReceiveBodyChunk(request: Request, data: Data)
    func didFinishReceivingBody(request: Request)
}

// MARK: Lifecycle
/// Parses HTTP requests and communicates the response.
public class Request {

    public fileprivate(set) var data = RequestData()

    internal enum Status {
        case success
        case headerLineCountOverflow
        case invalidHeaderDataReceived(Data)
        case noHTTPMethod
        case noURI
        case missingContentLength
        case missingChunkTrailer
        case unexpectedContentLength
        case invalidContentLength
        case invalidChunkSize
        case unknown(method: Method, atUri: String)
    }

    internal var headerLines = 0
    internal var contentLength = 0
    internal var contentLengthReceived = 0
    internal var chunkSize: UInt64 = 0
    internal var chunkSizeReceived: UInt64 = 0

    fileprivate var requestDelegate: RequestCompletionDelegate?
    fileprivate var bodyParsingDelegate: RequestBodyParsingDelegate?
    fileprivate let socket: RequestSocket

    init(socket: RequestSocket) {
        self.socket = socket
    }

    func start(delegate: RequestCompletionDelegate, bodyParsingDelegate: RequestBodyParsingDelegate?) {
        self.requestDelegate = delegate
        self.bodyParsingDelegate = bodyParsingDelegate
        socket.start(readDelegate: self, writeDelegate: self, queue: DispatchQueue(label: "RequestSocketQueue"))
    }

    /// Missing a stop function here.
}

// MARK: - Read Delegation
extension Request : RequestSocketReadDelegate {

    func receivedHeader(data receivedData: Data) {

        // Is this a malformed request?
        guard data.append(receivedData) else {
            requestDelegate!.reply(request: self, inSocket: socket, status: .invalidHeaderDataReceived(receivedData))
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
            requestDelegate!.reply(request: self, inSocket: socket, status: .noHTTPMethod)
            return
        }

        // Do we have a URI?
        guard let uriString = data.url?.relativeString else {
            requestDelegate!.reply(request: self, inSocket: socket, status: .noURI)
            return
        }

        let possibleTransferEncoding = data.headerField("Transfer-Encoding")
        let possibleContentLength = data.headerField("Content-Length")

        // Are we expecting a body?
        if let expectsBody = bodyParsingDelegate?.shouldAcceptBody(request: self, method: method, path: uriString), expectsBody {

            if let transferEncoding = possibleTransferEncoding, transferEncoding.caseInsensitiveCompare("Chunked") != .orderedSame {
                // 1. Chunked body
                contentLength = -1
            } else {
                // 2. Not Chunked body
                guard possibleContentLength != nil else {
                    requestDelegate!.reply(request: self, inSocket: socket, status: .missingContentLength)
                    return
                }

                guard let givenContentLengthString = possibleContentLength,
                    let givenContentLength = Int(givenContentLengthString) else {
                        requestDelegate!.reply(request: self, inSocket: socket, status: .invalidContentLength)
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
                        requestDelegate!.reply(request: self, inSocket: socket, status: .unexpectedContentLength)
                        return
                }
            }

            contentLength = 0
            contentLengthReceived = 0
        }

        requestDelegate!.reply(request: self, inSocket: socket, status: .success)
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

        bodyParsingDelegate?.didReceiveBodyChunk(request: self, data: data)

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
            requestDelegate!.reply(request: self, inSocket: socket, status: .missingChunkTrailer)
            return
        }
        
        socket.read(.ChunkSize)
    }
    
    func receivedChunkFooter(data: Data) {

        headerLines = headerLines + 1
        guard headerLines < 200 else {
            requestDelegate!.reply(request: self, inSocket: socket, status: .headerLineCountOverflow)
            return
        }

        guard data.count <= 2 else {
            // In the future we may want to append these to the request.
            // For now we ignore, and continue reading the footers, waiting for the final blank line.
            socket.read(.ChunkFooter)
            return
        }

        bodyParsingDelegate?.didFinishReceivingBody(request: self)
        requestDelegate!.reply(request: self, inSocket: socket, status: .success)
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
        requestDelegate!.reply(request: self, inSocket: socket, status: .success)
    }

    private func overflowDetected() {
        socket.stop()
        requestDelegate!.reply(request: self, inSocket: socket, status: .headerLineCountOverflow)
    }
}

// MARK: - Write Delegation
extension Request : RequestSocketWriteDelegate {

    func didSendResponse() {
        data = RequestData()
        headerLines = 0
        contentLength = 0
        contentLengthReceived = 0
        chunkSize = 0
        chunkSizeReceived = 0

    }
}

// MARK: - Enums
public enum Method : String {
    case HEAD
    case GET
    case POST
    case PUT
    case DELETE
    case Unknown
}
