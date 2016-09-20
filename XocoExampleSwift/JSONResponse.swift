//
//  JSONResponse.swift
//  Xocolatl
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

class JSONResponse : GenericResponse {

    fileprivate let jsonData: Data

    init(code: StatusCode, json: Any) throws {
        jsonData = try JSONSerialization.data(withJSONObject: json)
        super.init(code, body: jsonData)
    }

    init(code: StatusCode, jsonData: Data) {
        self.jsonData = jsonData
        super.init(code, body: self.jsonData)
    }
}
