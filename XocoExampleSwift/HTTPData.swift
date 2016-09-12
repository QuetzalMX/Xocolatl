//
//  RequestData.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/9/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation
import AppKit
import Quartz

/// Convenience class for naming purposes.
public class Request : HTTPData {

    override init() {
        super.init()
        headerData = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
    }

    var body : Body {
        return Body(content: Data())
    }

    var method : Method {

        guard
            let methodString = CFHTTPMessageCopyRequestMethod(headerData)?.takeRetainedValue() as? String,
            let method = Method(rawValue: methodString)
            else { return .Unknown }

        return method
    }

    var contentType: Body.ContentType {
        return Body.ContentType(value: headerField("Content-Type"))
    }
}

/// Convenience class that also handles status codes.
public class Response : HTTPData {

    let statusCode: StatusCode
    init(statusCode: StatusCode, http: HTTPVersion) {
        self.statusCode = statusCode
        super.init()
        headerData = CFHTTPMessageCreateResponse(nil, statusCode.value, nil, http.value as CFString).takeRetainedValue()
    }

    func setHeaderField(value: String, forKey key: String) {
        CFHTTPMessageSetHeaderFieldValue(headerData, key as CFString, value as CFString)
    }
}

/// Thin wrapper around Apple's CFHTTPMessage.
public class HTTPData {
    var headerData: CFHTTPMessage!
}

/// Headers
extension HTTPData {

    @discardableResult
    func appendHeaderData(_ data: Data) -> Bool {
        return data.withUnsafeBytes { CFHTTPMessageAppendBytes(headerData, $0, data.count) }
    }

    func headerField(_ key: String) -> String? {
        return CFHTTPMessageCopyHeaderFieldValue(headerData, key.lowercased() as CFString)?.takeRetainedValue() as? String
    }

    var headerComplete : Bool {
        return CFHTTPMessageIsHeaderComplete(headerData)
    }

    var headerFields : [String: String] {
        guard let headerFields = CFHTTPMessageCopyAllHeaderFields(headerData)?.takeRetainedValue() as? [String: String] else {
            return [:]
        }

        return headerFields
    }

    var version : String? {
        return CFHTTPMessageCopyVersion(headerData).takeRetainedValue() as String
    }

    var url : URL? {
        return CFHTTPMessageCopyRequestURL(headerData)?.takeRetainedValue() as? URL
    }
}

enum HTTPVersion {
    case v1_0
    case v1_1
    case v2_0

    var value : String {
        switch self {
            case .v1_0: return kCFHTTPVersion1_0 as String
            case .v1_1: return kCFHTTPVersion1_1 as String
            case .v2_0: return kCFHTTPVersion2_0 as String
        }
    }

}
