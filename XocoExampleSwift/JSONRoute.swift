//
//  JSONRoute.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/15/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

/// This class is a work in progress. It's here while I test how to best build a UI for macOS.
class JSONRoute {

    let givenPath: String
    let givenMethod: Method
    let givenResponse: Data

    init?(path: String, method: Method, response: String) {
        givenPath = path
        givenMethod = method

        guard let JSONData = response.data(using: .utf8) else { return nil }
        givenResponse = JSONData
    }
}

extension JSONRoute : Routable {
    var path: String { return givenPath }
    var method: Method { return givenMethod }

    func handle(_ route: Request, parameters: [String : String]) -> HTTPResponsive {
        return JSONResponse(code: .OK, jsonData: givenResponse)
    }
}
