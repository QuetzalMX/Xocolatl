//
//  GenericResponse.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

class GenericResponse {

    fileprivate let code: StatusCode
    fileprivate let bodyData: Data?

    fileprivate var offset = 0

    init(code: StatusCode, body: Data?) {
        self.code = code
        bodyData = body
    }

    static let httpDateFormatter: DateFormatter = {
        // Example: Sun, 06 Nov 1994 08:49:37 GMT
        // For some reason, using zzz in the format string produces GMT+00:00
        let httpDateFormatter = DateFormatter()
        httpDateFormatter.timeZone = TimeZone.init(abbreviation: "GMT")
        httpDateFormatter.dateFormat = "EEE, dd MMM y HH:mm:ss 'GMT'"
        httpDateFormatter.locale = Locale.init(identifier: "en_US")
        return httpDateFormatter
    }()
}

extension GenericResponse : Response {

    var statusCode: StatusCode { return code }

    var bodySent: Bool {
        guard let givenBodyData = bodyData else { return true }

        return offset >= givenBodyData.count
    }

    var contentLength: UInt {
        guard let givenBodyData = bodyData else { return 0 }

        return UInt(givenBodyData.count)
    }

    var additionalHeaders: [String: String] { return [:] }

    var data: ResponseData {
        let responseData = ResponseData(statusCode: code, http: .v1_1)

        if let givenBodyData = bodyData {
            responseData.body = Body(content: givenBodyData)
        }

        responseData.setHeaderField(value: "\(contentLength)", forKey: "Content-Length")
        responseData.setHeaderField(value: "bytes", forKey: "Accept-Ranges")
        responseData.setHeaderField(value: GenericResponse.httpDateFormatter.string(from: Date()), forKey: "Date")
        return responseData
    }

    func readBody(bytes: UInt) -> Data {

        guard let givenBodyData = bodyData else { return Data() }

        let dataSubrange = givenBodyData.subdata(in: offset..<Int(bytes))
        offset = offset + dataSubrange.count
        return dataSubrange
    }
}
