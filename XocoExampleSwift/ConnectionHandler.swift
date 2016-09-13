//
//  Request.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/7/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

public enum Method : String {
    case HEAD
    case GET
    case POST
    case PUT
    case DELETE
    case Unknown
}

enum ContentType {

    case URLEncoded
    case JSON
    case PDF
    case FormData
    case Text
    case Image
    case Other(_: String)

    init(value: String?) {

        guard let caseInsensitiveValue = value?.lowercased() else {
            self = .Other("")
            return
        }

        if caseInsensitiveValue.contains("json") {
            self = .JSON
        } else if caseInsensitiveValue.contains("x-www-form-urlencoded") {
            self = .URLEncoded
        } else if caseInsensitiveValue.contains("pdf") {
            self = .PDF
        } else if caseInsensitiveValue.contains("multipart/form-data") {
            self = .FormData
        } else if caseInsensitiveValue.contains("text/") {
            self = .Text
        } else if caseInsensitiveValue.contains("image/png") {
            self = .Image
        } else {
            self = .Other(caseInsensitiveValue)
        }
    }
}

/// Handles the parsing of information from an internal socket to an actual Request object.
public class ConnectionHandler {

    /// This is a wrapper around the HTTP request. The goal is to make this as complete as possible.
    internal var request = Request()

    /// Since this handler is reused, this status changes constantly.
    var status: Status
    internal enum Status {
        /// We're waiting for requests
        case listening

        /// Should be in this state when reading and until we either fail or report success.
        case parsing

        /// We're out of commission.
        case stopped
    }

    /// Notified when `request` is ready to be responded to or if we failed to parse it.
    internal var delegate: RequestDelegate?

    /// Optionally notified whenever we need a different way to parse the request's body.
    internal var bodyParsingDelegate: RequestBodyParsingDelegate?

    /// Internal socket
    fileprivate let socket: RequestSocket

    /// We do not create our own sockets, we only handle sockets that the Server has created for us.
    ///
    /// - parameter socket: a socket that the Server has created for us
    ///
    /// - returns: a ConnectionHandler ready to start parsing
    init(socket: RequestSocket) {
        self.socket = socket
        status = .stopped
    }
}

extension ConnectionHandler {

    /// Start listening for requests (i.e. data) coming from the socket.
    ///
    /// - parameter delegate:            notified whenever we're done
    /// - parameter bodyParsingDelegate: optionally notified regarding parsing the incoming requests' body
    func beginParsing(delegate: RequestDelegate, bodyParsingDelegate: RequestBodyParsingDelegate?) {

        guard Status.parsing != status else { return }
        status = .parsing

        self.delegate = delegate
        self.bodyParsingDelegate = bodyParsingDelegate
        socket.start(readDelegate: self,
                     writeDelegate: self,
                     queue: DispatchQueue(label: "RequestSocketQueue"))
    }

    func read(_ part: HTTPPart.Request) {
        socket.read(part)
    }

    func respond(with response: HTTPResponsive) {
        // Write the header response.
//        socket.respond(.PartialHeaders,
//                       data: response.data.rawData)
//
//        let responseBody = response.receivedData.body
//        if !responseBody.isEmpty {
//            socket.respond(.WholeResponse,
//                           data: responseBody)
//        }
    }

    func closeConnection() {
        socket.stop()
        status = .stopped
    }
}
