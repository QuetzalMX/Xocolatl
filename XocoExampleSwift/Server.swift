//
//  Server.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/7/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

/// The server handles the lifecycle of Requests.
public class Server {

    /// Handles responses to incoming connections.
    fileprivate var responseDelegate: ConnectionHandlerDelegate!

    /// Optionally handles the body parsing of requests.
    fileprivate var bodyParsingDelegate: RequestBodyParsingDelegate?

    /// Handles parsingg of incoming connections from clients.
    private let incomingConnectionsSocket: ServerSocket

    init(certificatePath: String, certificatePassword: String) throws {

        // Parse the certificate.
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)) else { fatalError(".p12 data not found at path \(certificatePath)") }

        // Get the private key from the certificate using the password.
        var privateKeyRef: CFArray? = nil
        let options = [kSecImportExportPassphrase as NSString : certificatePassword]
        let securityError = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &privateKeyRef)
        guard securityError == noErr else { fatalError("Could not import the private key from the .p12 file. OSSStatus: \(securityError)") }

        // Fetch the identity.
        let unsafeIdentityDict = CFArrayGetValueAtIndex(privateKeyRef, 0)
        let identityDict = unsafeBitCast(unsafeIdentityDict, to: CFDictionary.self)
        let unsafeIdentityRef = CFDictionaryGetValue(identityDict, unsafeBitCast(kSecImportItemIdentity, to: UnsafeRawPointer.self))
        let identityRef = unsafeBitCast(unsafeIdentityRef, to: SecIdentity.self)

        // And now copy the certificate
        var cert: SecCertificate?
        let status = SecIdentityCopyCertificate(identityRef, &cert)
        guard status == noErr else { fatalError("Could not import the certificate from the .p12 file. OSStatus: \(status)") }

        guard let certificate = cert else { fatalError("Something went wrong when parsing the identity and certificate") }

        // The socket will pass them to the incoming requests.
        incomingConnectionsSocket = ServerSocket(sslIdentity: identityRef, sslCertificate: certificate)
    }

    /// Starts listening for incoming requests.
    ///
    /// - parameter responseDelegate: provides a Response to requests we receive
    ///
    /// - throws: if the socket cannot begin listening for requests
    public func start(responseDelegate: ConnectionHandlerDelegate, requestBodyParsingDelegate: RequestBodyParsingDelegate? = nil) throws {
        self.responseDelegate = responseDelegate
        self.bodyParsingDelegate = requestBodyParsingDelegate

        try incomingConnectionsSocket.start(atPort: 3000, delegate: self)
    }
}

//MARK: Incoming Requests
extension Server : ServerSocketDelegate {

    /// Once the socket received a request, it'll put it in a package and deliver it to us.
    /// This request has not begun accepting any data. It is our responsibility to start it when we see fit.
    ///
    /// - parameter request: the incoming request
    internal func received(incomingRequest: ConnectionHandler) {
        incomingRequest.beginParsing(delegate: responseDelegate, bodyParsingDelegate: bodyParsingDelegate)
    }
}
