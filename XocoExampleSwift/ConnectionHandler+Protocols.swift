//
//  ConnectionHandlerDelegates.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/11/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

/// Once a request is either completed or failed to be parsed, it is forwarded to our delegate.
public protocol ConnectionHandlerDelegate {
    func reply(request: Request, fromHandler handler: ConnectionHandler)
}

/// Optionally accept the request's body and save it as necessary.
public protocol RequestBodyParsingDelegate {

    /// Once a request is received and the headers parsed, it requests instructions regarding parssing or ignoring the incoming body.
    /// If no delegate is present, we accept the body for POST and PUT requests.
    ///
    /// - parameter request: the request that would own the body
    /// - parameter method:  the type of request
    /// - parameter path:    the path of the request
    ///
    /// - returns: true if this request should parse the incoming body
    func shouldAcceptBody(request: ConnectionHandler, method: Method, path: String) -> Bool

    /// This method is called after receiving all HTTP headers, but before reading any of the request body.
    /// You should allocate buffers, file handles, or whatever you need to process a body of this length.
    /// If no delegate is present, nothing happens.
    ///
    /// - parameter request:  the request about to receive a body
    /// - parameter bodySize: the size of the body
    func willReceiveBody(request: ConnectionHandler, bodySize: Int)

    /// Called whenever a piece of the body (which may be the entirety of the body) is received.
    /// This method may be called multiple times for the same request if the body is more than one chunk of data.
    /// If no delegate is present, we append the data to the request.
    ///
    /// - parameter request: the request that owns the receiving body
    /// - parameter data:    a part or all of the body
    func didReceiveBodyChunk(request: ConnectionHandler, data: Data)

    /// Once the body has been parsed, clean up here if needed.
    /// If no delegate is present, nothing happens.
    ///
    /// - parameter request: the request that just parsed its body.
    func didFinishReceivingBody(request: ConnectionHandler)
}
