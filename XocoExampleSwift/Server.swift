//
//  Server.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/7/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

/// The server has two responsibilities:
/// 1. Listen for incoming requests.
/// 2. Answer incoming requests.
///
/// Once a request is ready to be answered, our delegate will give us a valid response.
public protocol ServerDelegate {
    func respond(_ request: Request) -> Response?
}

public let ReceivedRequest = Notification.Name("ReceivedRequest")

public class Server {

    /// Handles what happens whenever a Request finishes (success or failure)
    fileprivate var responseDelegate: ServerDelegate? = nil

    /// Handles incoming connections from clients.
    fileprivate let incomingConnectionsSocket: ServerSocket

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
    public func start(responseDelegate: ServerDelegate) throws {
        self.responseDelegate = responseDelegate
        try incomingConnectionsSocket.start(atPort: 3000, delegate: self)
    }
}

//MARK: Incoming REquests
extension Server : ServerSocketDelegate {

    /// Once the socket received a request, it'll put it in a package and deliver it to us.
    /// This request has not begun accepting any data. It is our responsibility to start it when we see fit.
    ///
    /// - parameter request: the incoming request
    internal func received(incomingRequest: Request) {
        incomingRequest.start(delegate: self, bodyParsingDelegate: self)
    }
}

//MARK: - Responding to Requests
extension Server : RequestCompletionDelegate {

    // Result
    func reply(request: Request, inSocket socket: RequestSocket, status: Request.Status) {

        NotificationCenter.default.post(name: Notification.Name("ReceivedRequest"),
                                        object: request)

        // Could we parse the request?
        guard case .success = status else {
            return
        }

        // We could. Respond.
        guard let response = responseDelegate?.respond(request) else {
            // Our delegate won't respond. 500.
            let invalidRequest = GenericResponse(code: .GenericServerError, body: nil)
            socket.respond(.PartialHeaders, data: invalidRequest.data.rawData)
            return
        }

        // Write the header response.
        socket.respond(.PartialHeaders,
                       data: response.data.rawData)

        let responseBody = response.data.body
        if !responseBody.isEmpty {
            socket.respond(.WholeResponse,
                           data: responseBody)
        }
    }
}

//MARK: - Parsing Request Body
extension Server : RequestBodyParsingDelegate {

    func shouldAcceptBody(request: Request, method: Method, path: String) -> Bool {
        switch method {

        case .POST, .PUT:
            return true
        default:
            return false

        }
    }

    func willReceiveBody(request: Request, bodySize: Int) {
        // This method is called after receiving all HTTP headers, but before reading any of the request body.
        // Override me to allocate buffers, file handles, etc.
    }

    func didReceiveBodyChunk(request: Request, data: Data) {
        // Override me to do something useful with a POST / PUT.
        // If the post is small, such as a simple form, you may want to simply append the data to the request.
        // If the post is big, such as a file upload, you may want to store the file to disk.
        //
        // Remember: In order to support LARGE POST uploads, the data is read in chunks.
        // This prevents a 50 MB upload from being stored in RAM.
        // The size of the chunks are limited by the POST_CHUNKSIZE definition.
        // Therefore, this method may be called multiple times for the same POST request.
        guard request.data.append(data) else { return }
    }

    func didFinishReceivingBody(request: Request) {
        // This method is called after the request body has been fully read but before the HTTP request is processed.
        // Override me to perform any final operations on an upload.
        // For example, if you were saving the upload to disk this would be
        // the hook to flush any pending data to disk and maybe close the file.
    }
}
