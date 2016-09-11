//
//  ResponseProtocol.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

public protocol Response {

    /// The underlying HTTP message
    var data: ResponseData { get }

    /// If you don't know the length in advance, implement the isChunked method and have it return YES.
    var contentLength: UInt { get }

    /// The returned data's length must always be less than or equal to the requested length.
    func readBody(bytes: UInt) -> Data

    /// If invoking readBody(bytes:) returns empty data, this method should return true.
    var bodySent: Bool { get }

    /// The response's HTTP code.
    var statusCode: StatusCode { get }

    /// Response-specific headers.
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
