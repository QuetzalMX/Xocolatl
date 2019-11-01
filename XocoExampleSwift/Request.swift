//
//  ConnectionHandler+Request.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/12/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

/// This is a reusable request. Its goal is to parse incoming bytes from the socket into a CFHTTPMessage.
public class Request : HTTPData {

    var headerLines = 0
    var contentLength = 0
    var contentLengthReceived = 0
    var chunkSize: UInt64 = 0
    var chunkSizeReceived: UInt64 = 0

    var status : Status = .parsingInProgress
    enum Status {
        case parsingInProgress
        case success
        case headerLineCountOverflow
        case invalidHeaderDataReceived(Data)
        case noHTTPMethod
        case noURI
        case missingContentLength
        case missingChunkTrailer
        case unexpectedContentLength
        case invalidContentLength
        case invalidChunkSize
        case unknown(method: Method, atUri: String)

        static func ==(lhs: Status, rhs: Status) -> Bool {

            switch (lhs, rhs) {

                case (.parsingInProgress, .parsingInProgress):                  return true
                case (.success, .success):                                      return true
                case (.headerLineCountOverflow, .headerLineCountOverflow):      return true
                case (.invalidHeaderDataReceived, .invalidHeaderDataReceived):  return true
                case (.noHTTPMethod, .noHTTPMethod):                            return true
                case (.noURI, .noURI):                                          return true
                case (.missingContentLength, .missingContentLength):            return true
                case (.missingChunkTrailer, .missingChunkTrailer):              return true
                case (.unexpectedContentLength, .unexpectedContentLength):      return true
                case (.invalidContentLength, .invalidContentLength):            return true
                case (.invalidChunkSize, .invalidChunkSize):                    return true

                case (.unknown(let methodL, let uriL), .unknown(let methodR, let uriR)):
                    return (methodL == methodR) && (uriL == uriR)

                default: return false

            }
        }
    }

    override init() {
        super.init()
        headerData = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
    }

    var method : Method {

        guard
			let methodString = CFHTTPMessageCopyRequestMethod(headerData)?.takeRetainedValue() as String?,
            let method = Method(rawValue: methodString)
            else { return .Unknown }

        return method
    }

    var contentType: ContentType {
        return ContentType(value: headerField("Content-Type"))
    }

}
