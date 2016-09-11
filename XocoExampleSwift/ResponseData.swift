//
//  ResponseData.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

public class ResponseData : RequestData {

    init(code: StatusCode) {
        super.init()
        receivedData = CFHTTPMessageCreateResponse(nil, code.value, nil, kCFHTTPVersion1_1).takeRetainedValue()
    }

    var status : StatusCode {
        get {
            let statusInt = CFHTTPMessageGetResponseStatusCode(receivedData)
            return StatusCode(value: statusInt)
        }
    }
}
