//
//  RequestBody.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/11/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

protocol Parseable {
    associatedtype Value
    func parse() -> Value?
}

class Body {

    let content: Data
    init(content: Data) {
//        get {
//            guard let data = CFHTTPMessageCopyBody(receivedData)?.takeRetainedValue() as? Data else { return Data() }
//            return data
//        }
//
//        set {
//            CFHTTPMessageSetBody(receivedData, newValue as CFData)
//        }

        self.content = content
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
}

class JSONBody : Body, Parseable {
    typealias Value = Any

    internal func parse() -> Any? {
        return try? JSONSerialization.jsonObject(with: content)
    }
}

class URLEncodedBody : Body, Parseable {
    typealias Value = [[String: String]]

    internal func parse() -> [[String : String]]? {
        // Get the whole encoded string.
        guard let encodedParametersString = String(data: content, encoding: .utf8) else { return nil }

        // Separate each pair from the string.
        let encodedParameterPairsString = encodedParametersString.components(separatedBy: "&")

        // Parse each pair into a [String: String] object.
        return encodedParameterPairsString
            .map { encodedPairString -> [String: String]? in

                let encodedPair = encodedPairString.components(separatedBy: "=")
                guard encodedPair.count == 2 else { return nil }

                return [encodedPair[0]: encodedPair[1]]
            }
            .flatMap { $0 }
    }
}
