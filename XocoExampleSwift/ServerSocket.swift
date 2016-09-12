//
//  ServerSocket.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/8/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

// MARK: Protocols
protocol ServerSocketDelegate {
    func received(incomingRequest: ConnectionHandler)
}

// MARK: Lifecycle
/// Listens, prepares for SSL and forwards requests to its delegate. Uses an internal read-only socket.
class ServerSocket {

    // Notified when a new request begins.
    fileprivate var delegate: ServerSocketDelegate!

    // These are needed to begin the SSL negotiation.
    fileprivate let sslIdentity: SecIdentity
    fileprivate let sslCertificate: SecCertificate

    // Handles the raw connection to the client.
    fileprivate let internalSocket = GCDAsyncSocket()

    init(sslIdentity: SecIdentity, sslCertificate: SecCertificate) {
        self.sslIdentity = sslIdentity
        self.sslCertificate = sslCertificate
    }

    func start(atPort port: UInt16, delegate: ServerSocketDelegate) throws {
        self.delegate = delegate

        // We _must_ set both the delegate and delegate queue before accepting connections
        internalSocket.delegate = self
        internalSocket.delegateQueue = DispatchQueue(label: "ServerSocketQueue")

        try internalSocket.accept(onInterface: "", port: port)
    }
}

// MARK: Read Delegation
extension ServerSocket : GCDAsyncSocketDelegate {

    @objc func socket(_ serverSocket: GCDAsyncSocket, didAcceptNewSocket requestSocket: GCDAsyncSocket) {
        let newSocket = RequestSocket(socket: requestSocket,
                                      sslIdentity: sslIdentity,
                                      sslCertificate: sslCertificate)

        let newRequest = ConnectionHandler(socket: newSocket)

        delegate!.received(incomingRequest: newRequest)
    }
}
