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
public class RequestData : HTTPData {

    override init() {
        super.init()
        receivedData = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
    }
}

/// Convenience class that also handles status codes.
public class ResponseData : HTTPData {

    let statusCode: StatusCode
    init(statusCode: StatusCode, http: HTTPVersion) {
        self.statusCode = statusCode
        super.init()
        receivedData = CFHTTPMessageCreateResponse(nil, statusCode.value, nil, http.value as CFString).takeRetainedValue()
    }

    override var body: Body {
        // This is wrong
        get {
            let wrongValue = ""
            guard let data = CFHTTPMessageCopyBody(receivedData)?.takeRetainedValue() as? Data else { return Body(content: Data()) }
            return Body(content: data)
        }

        set {
            CFHTTPMessageSetBody(receivedData, newValue.content as CFData)
        }
    }
}

/// Thin wrapper around Apple's CFHTTPMessage.
public class HTTPData {
    fileprivate var receivedData: CFHTTPMessage!

    /// This needs to be temporarily here because we cannot override properties from extensions.
    var body : Body {
        return Body(content: Data())
    }
}

extension HTTPData {

    @discardableResult
    func append(_ data: Data) -> Bool {
        return data.withUnsafeBytes { CFHTTPMessageAppendBytes(receivedData, $0, data.count) }
    }

    func setHeaderField(value: String, forKey key: String) {
        CFHTTPMessageSetHeaderFieldValue(receivedData, key as CFString, value as CFString)
    }

    func headerField(_ key: String) -> String? {
        return CFHTTPMessageCopyHeaderFieldValue(receivedData, key.lowercased() as CFString)?.takeRetainedValue() as? String
    }

    var rawData : Data {
        guard let unmanagedData = CFHTTPMessageCopySerializedMessage(receivedData) else { return Data() }

        return unmanagedData.takeRetainedValue() as Data
    }

    var headerComplete : Bool {
        return CFHTTPMessageIsHeaderComplete(receivedData)
    }

    var version : String? {
        return CFHTTPMessageCopyVersion(receivedData).takeRetainedValue() as String
    }

    var method : Method {

        guard
            let methodString = CFHTTPMessageCopyRequestMethod(receivedData)?.takeRetainedValue() as? String,
            let method = Method(rawValue: methodString)
            else { return .Unknown }

        return method
    }

    var url : URL? {
        return CFHTTPMessageCopyRequestURL(receivedData)?.takeRetainedValue() as? URL
    }

    var headerFields : [String: String] {
        guard let headerFields = CFHTTPMessageCopyAllHeaderFields(receivedData)?.takeRetainedValue() as? [String: String] else { return [:] }
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
