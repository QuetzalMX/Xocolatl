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
    var headerData: CFHTTPMessage!

    fileprivate func appendHTTPData(_ data: Data) -> Bool {
        return data.withUnsafeBytes { CFHTTPMessageAppendBytes(headerData, $0, data.count) }
    }

    // Body has to be declared here because we cannot override properties declared in an extension.
    var body : Data {
        guard let content = CFHTTPMessageCopyBody(headerData)?.takeRetainedValue() else { return Data() }

        return content as Data
    }
}

extension HTTPData {

    @discardableResult
    func appendHeaderData(_ data: Data) -> Bool {
        return appendHTTPData(data)
    }

    @discardableResult
    func appendBodyData(_ data: Data) -> Bool {
        return appendHTTPData(data)
    }

    func headerField(_ key: String) -> String? {
        return CFHTTPMessageCopyHeaderFieldValue(headerData, key.lowercased() as CFString)?.takeRetainedValue() as? String
    }

    var headerComplete : Bool {
        return CFHTTPMessageIsHeaderComplete(headerData)
    }

    var rawHeaderData : Data {
        guard let rawData = CFHTTPMessageCopySerializedMessage(headerData)?.takeRetainedValue() else { return Data() }
        return rawData as Data
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
