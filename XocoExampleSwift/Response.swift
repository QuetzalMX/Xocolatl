//
//  Response.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/11/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

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

    override var body: Data {

        get {
            return super.body
        }

        set {
            CFHTTPMessageSetBody(headerData, newValue as CFData)
        }
    }
}
