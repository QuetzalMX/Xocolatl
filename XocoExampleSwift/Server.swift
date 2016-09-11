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

    /// Handles the parsing of any incoming request's body.
    fileprivate var requestBodyParsingDelegate: RequestBodyParsingDelegate?

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
    public func start(responseDelegate: ServerDelegate, requestBodyParsingDelegate: RequestBodyParsingDelegate? = nil) throws {
        self.responseDelegate = responseDelegate
        self.requestBodyParsingDelegate = requestBodyParsingDelegate ?? self
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

/// The server will forward all of these methods to the requestBodyParsingDelegate if it exists.
extension Server : RequestBodyParsingDelegate {

    /// Once a request is received and the headers parsed, it requests instructions regarding parssing or ignoring the incoming body.
    /// Default behavior is to accept body for POST and PUT requests.
    ///
    /// - parameter request: the request that would own the body
    /// - parameter method:  the type of request
    /// - parameter path:    the path of the request
    ///
    /// - returns: true if this request should parse the incoming body
    public func shouldAcceptBody(request: Request, method: Method, path: String) -> Bool {

        guard let bodyParsingDelegate = requestBodyParsingDelegate else {
            return (.POST == method || .PUT == method)
        }

        return bodyParsingDelegate.shouldAcceptBody(request: request, method: method, path: path)
    }

    /// This method is called after receiving all HTTP headers, but before reading any of the request body.
    /// You should allocate buffers, file handles, or whatever you need to process a body of this length.
    /// Default behavior is empty.
    ///
    /// - parameter request:  the request about to receive a body
    /// - parameter bodySize: the size of the body
    public func willReceiveBody(request: Request, bodySize: Int) {
        requestBodyParsingDelegate?.willReceiveBody(request: request, bodySize: bodySize)
    }

    /// Called whenever a piece of the body (which may be the entirety of the body) is received.
    /// This method may be called multiple times for the same request if the body is more than one chunk of data.
    /// Default behavior is to append the data to the request.
    ///
    /// - parameter request: the request that owns the receiving body
    /// - parameter data:    a part or all of the body
    public func didReceiveBodyChunk(request: Request, data: Data) {

        guard let bodyParsingDelegate = requestBodyParsingDelegate else {
            let _ = request.data.append(data)
            return
        }

        bodyParsingDelegate.didReceiveBodyChunk(request: request, data: data)
    }

    /// Once the body has been parsed, clean up here if needed.
    /// Default implementation is empty.
    ///
    /// - parameter request: the request that just parsed its body.
    public func didFinishReceivingBody(request: Request) {
        requestBodyParsingDelegate?.didFinishReceivingBody(request: request)
    }

}
