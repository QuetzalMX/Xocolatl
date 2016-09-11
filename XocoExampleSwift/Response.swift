//
//  ResponseProtocol.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

public protocol Response {

    var data: ResponseData { get }
    /**
     * Returns the length of the data in bytes.
     * If you don't know the length in advance, implement the isChunked method and have it return YES.
     **/
    var contentLength: UInt { get }

    /**
     * Returns the data for the response.
     * You do not have to return data of the exact length that is given.
     * You may optionally return data of a lesser length.
     * However, you must never return data of a greater length than requested.
     * Doing so could disrupt proper support for range requests.
     *
     * To support asynchronous responses, read the discussion at the bottom of this header.
     **/
    func read(bytes: UInt) -> Data

    /**
     * Should only return YES after the HTTPConnection has read all available data.
     * That is, all data for the response has been returned to the HTTPConnection via the readDataOfLength method.
     **/
    var bodySent: Bool { get }

    /**
     * Status code for response.
     * Allows for responses such as redirect (301), etc.
     **/
    var status: StatusCode { get }

    /**
     * If you want to add any extra HTTP headers to the response,
     * simply return them in a dictionary in this method.
     **/
    var additionalHeaders: [String: String] { get }
}

public enum StatusCode {

    case Informational
    case OK
    case Redirect
    case GenericClientError
    case GenericServerError
    case Unknown

    init(value: Int) {
        switch value {
        case 100: self = .Informational
        case 200: self = .OK
        case 300: self = .Redirect
        case 400: self = .GenericClientError
        case 500: self = .GenericServerError

        default: self = .Unknown
        }
    }

    var value: Int {
        switch self {
        case .Informational:         return 100
        case .OK:                    return 200
        case .Redirect:              return 300
        case .GenericClientError:    return 400
        case .GenericServerError:    return 500
        case .Unknown:               return 500
        }
    }
}
