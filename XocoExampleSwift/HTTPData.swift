//
//  RequestData.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/9/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation
import AppKit
import Quartz

/// Thin wrapper around Apple's CFHTTPMessage.
public class HTTPData {
    var rawData: CFHTTPMessage!

    /// This needs to be temporarily here because we cannot override properties from extensions.
    var body : Body {
        return Body(content: Data())
    }
}

/// Convenience class for naming purposes.
public class Request : HTTPData {

    override init() {
        super.init()
        rawData = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
    }
}

/// Convenience class that also handles status codes.
public class Response : HTTPData {

    let statusCode: StatusCode
    init(statusCode: StatusCode, http: HTTPVersion) {
        self.statusCode = statusCode
        super.init()
        rawData = CFHTTPMessageCreateResponse(nil, statusCode.value, nil, http.value as CFString).takeRetainedValue()
    }

    override var body: Body {
        // This is wrong
        get {
            let wrongValue = ""
            guard let data = CFHTTPMessageCopyBody(rawData)?.takeRetainedValue() as? Data else { return Body(content: Data()) }
            return Body(content: data)
        }

        set {
            CFHTTPMessageSetBody(rawData, newValue.content as CFData)
        }
    }
}

extension HTTPData {

    @discardableResult
    func append(_ data: Data) -> Bool {
        return data.withUnsafeBytes { CFHTTPMessageAppendBytes(rawData, $0, data.count) }
    }

    func setHeaderField(value: String, forKey key: String) {
        CFHTTPMessageSetHeaderFieldValue(rawData, key as CFString, value as CFString)
    }

    func headerField(_ key: String) -> String? {
        return CFHTTPMessageCopyHeaderFieldValue(rawData, key.lowercased() as CFString)?.takeRetainedValue() as? String
    }

    var rawData : Data {
        guard let unmanagedData = CFHTTPMessageCopySerializedMessage(rawData) else { return Data() }

        return unmanagedData.takeRetainedValue() as Data
    }

    var headerComplete : Bool {
        return CFHTTPMessageIsHeaderComplete(rawData)
    }

    var version : String? {
        return CFHTTPMessageCopyVersion(rawData).takeRetainedValue() as String
    }

    var method : Method {

        guard
            let methodString = CFHTTPMessageCopyRequestMethod(rawData)?.takeRetainedValue() as? String,
            let method = Method(rawValue: methodString)
            else { return .Unknown }

        return method
    }

    var url : URL? {
        return CFHTTPMessageCopyRequestURL(rawData)?.takeRetainedValue() as? URL
    }

    var headerFields : [String: String] {
        guard let headerFields = CFHTTPMessageCopyAllHeaderFields(rawData)?.takeRetainedValue() as? [String: String] else { return [:] }
        return headerFields
    }
}

extension HTTPData {

    var contentType: Body.ContentType {
        return Body.ContentType(value: headerField("Content-Type"))
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
