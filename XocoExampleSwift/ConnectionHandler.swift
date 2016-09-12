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

/// Handles the parsing of information from an internal socket to an actual Request object.
public class ConnectionHandler {

    /// This is the actual HTTP request. The goal is to make this as complete as possible.
    internal var data = Request()

    /// Did we manage to parse it?
    var status: Status
    internal enum Status {
        case created
        case parsing

        /// Results
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

    /// Used when parsing.
    internal var headerLines = 0
    internal var contentLength = 0
    internal var contentLengthReceived = 0
    internal var chunkSize: UInt64 = 0
    internal var chunkSizeReceived: UInt64 = 0

    /// Our delegates
    internal var delegate: ConnectionHandlerDelegate?
    internal var bodyParsingDelegate: RequestBodyParsingDelegate?

    /// Internal socket
    internal let socket: RequestSocket

    init(socket: RequestSocket) {
        self.socket = socket
        status = .created
    }
    
    func beginParsing(delegate: ConnectionHandlerDelegate, bodyParsingDelegate: RequestBodyParsingDelegate?) {
        self.delegate = delegate
        self.bodyParsingDelegate = bodyParsingDelegate

        socket.start(readDelegate: self, writeDelegate: self, queue: DispatchQueue(label: "RequestSocketQueue"))

        status = .parsing
    }

    func respond(with response: HTTPResponsive) {
        // Write the header response.
//        socket.respond(.PartialHeaders,
//                       data: response.receivedData.rawData)
//
//        let responseBody = response.receivedData.body
//        if !responseBody.isEmpty {
//            socket.respond(.WholeResponse,
//                           data: responseBody)
//        }
    }

    /// Missing a stop function here.
}
