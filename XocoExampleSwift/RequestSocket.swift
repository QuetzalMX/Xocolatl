//
//  RequestSocket.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/8/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

// MARK: Read/Write Protocols
protocol RequestSocketReadDelegate {
    func receivedHeader(data: Data)
    func receivedChunkSize(data: Data)
    func receivedChunkData(data: Data)
    func receivedChunkTrailer(data: Data)
    func receivedChunkFooter(data: Data)
    func receivedBody(data: Data)
}

protocol RequestSocketWriteDelegate {
    func didSendResponse()
}

// MARK: Lifecycle

/// Parses HTTP requests and responds to them. Uses a read-write, reusable internal socket.
class RequestSocket {

    /// All received/sent packets are pre-processed for our delegates' convenience.
    fileprivate(set) var readDelegate: RequestSocketReadDelegate?
    fileprivate(set) var writeDelegate: RequestSocketWriteDelegate?

    /// SSL info and socket
    fileprivate let internalSocket: GCDAsyncSocket
    fileprivate let settings: [String: NSObject]

    init(socket: GCDAsyncSocket, sslIdentity: SecIdentity, sslCertificate: SecCertificate) {
        internalSocket = socket

        let sslInfo: [AnyObject] = [sslIdentity, sslCertificate]
        settings = [
            kCFStreamSSLIsServer as String: true as NSNumber,
            kCFStreamSSLCertificates as String: sslInfo as NSObject,
        ]
    }

    /// Begin accepting the request, but negotiate TLS first.
    func start(readDelegate: RequestSocketReadDelegate, writeDelegate: RequestSocketWriteDelegate, queue: DispatchQueue) {

        // Delegation.
        self.readDelegate = readDelegate
        self.writeDelegate = writeDelegate
        internalSocket.delegate = self
        internalSocket.delegateQueue = queue

        // Starting TLS is asynchronous to us, but the socket is smart enough to queue further reads until we have a TLS connection.
        // So, it's okay if we "begin reading" right away.
        internalSocket.startTLS(settings)

        read(.Header)
    }

    /// https://www.youtube.com/watch?v=z0Z1RqV4Y1k
    func stop() {
        internalSocket.disconnect()
    }
}

// MARK: Read/Write
fileprivate let maxHeaderLineLength = UInt(8190)
fileprivate let maxChunkLength      = UInt(200)
fileprivate let timeoutReadBody     = Double(-1)

extension RequestSocket {

    /// Read part of a request through the internal socket.
    func read(_ part: HTTPPart.Request) {

        switch part {

        case .Header:
            let firstHeaderLineTimeout = 30.0
            internalSocket.readData(to: GCDAsyncSocket.crlfData(),
                                    withTimeout: firstHeaderLineTimeout,
                                    maxLength: maxHeaderLineLength,
                                    tag: HTTPPart.request(part).tag)

        case .Body(let bytesToRead):
            internalSocket.readData(toLength: bytesToRead,
                                    withTimeout: timeoutReadBody,
                                    tag: HTTPPart.request(part).tag)

        case .ChunkSize:
            internalSocket.readData(to: GCDAsyncSocket.crlfData(),
                                    withTimeout: timeoutReadBody,
                                    maxLength: maxChunkLength,
                                    tag: HTTPPart.request(part).tag)

        case .ChunkData(let bytesToRead):
            internalSocket.readData(toLength: bytesToRead,
                                    withTimeout: timeoutReadBody,
                                    tag: HTTPPart.request(part).tag)

        case .ChunkTrailer:
            internalSocket.readData(toLength: 2,
                                    withTimeout: timeoutReadBody,
                                    tag: HTTPPart.request(part).tag)

        case .ChunkFooter:
            internalSocket.readData(to: GCDAsyncSocket.crlfData(),
                                    withTimeout: timeoutReadBody,
                                    maxLength: maxHeaderLineLength,
                                    tag: HTTPPart.request(part).tag)
        }
    }

    /// Send part of a response through the internal socket.
    func respond(_ part: HTTPPart.Response, data: Data) {
        internalSocket.write(data,
                             withTimeout: 30,
                             tag: HTTPPart.response(part).tag)
    }
}

// MARK: Read/Write Delegation
extension RequestSocket : GCDAsyncSocketDelegate {

    /// Received part of a request.
    @objc func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {

        switch tag {

            case HTTPPart.request(.Header).tag:
                readDelegate!.receivedHeader(data: data)

            case HTTPPart.request(.ChunkSize).tag:
                readDelegate!.receivedChunkSize(data: data)

            case HTTPPart.request(.ChunkData(bytesToRead: 0)).tag:
                readDelegate!.receivedChunkData(data: data)

            case HTTPPart.request(.ChunkTrailer).tag:
                readDelegate!.receivedChunkTrailer(data: data)

            case HTTPPart.request(.ChunkFooter).tag:
                readDelegate!.receivedChunkFooter(data: data)

            case HTTPPart.request(.Body(bytesToRead: 0)).tag:
                readDelegate!.receivedBody(data: data)

            default:
                break
        }
    }

    /// Sent part of a response.
    @objc func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {

        switch tag {

            case HTTPPart.response(.PartialHeaders).tag:
                break

            case HTTPPart.response(.WholeResponse).tag:
                writeDelegate!.didSendResponse()

            default:
                break
        }
    }
}

// MARK: Enums
/// Used by the read/write methods as a parameter. Must be at least `internal`.
internal enum HTTPPart {

    case request(_: Request)
    case response(_: Response)

    public enum Request {
        case Header
        case Body(bytesToRead: UInt)
        case ChunkSize
        case ChunkData(bytesToRead: UInt)
        case ChunkTrailer
        case ChunkFooter
    }

    public enum Response {
        case PartialHeaders
        case WholeResponse
    }
}

/// Used by the read/write methods to communicate with our internal socket.
fileprivate extension HTTPPart {
    var tag: Int {

        switch self {

        case .request(let part):
            switch part {
            case .Header:       return 10
            case .Body:         return 11
            case .ChunkSize:    return 12
            case .ChunkData:    return 13
            case .ChunkTrailer: return 14
            case .ChunkFooter:  return 15
            }

        case .response(let part):
            switch part {
            case .PartialHeaders:   return 21
            case .WholeResponse:    return 90
            }
        }
    }
}
