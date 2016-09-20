//
//  GenericRoute.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/14/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

class GenericRoute {

    let givenPath: String
    let givenMethod: Method
    init(path: String, method: Method) {
        givenPath = path
        givenMethod = method
    }

}

extension GenericRoute : Routable {
    var path: String { return givenPath }
    var method: Method { return givenMethod }

    func handle(_ route: Request, parameters: [String : String]) -> HTTPResponsive {
        return try! JSONResponse(code: .OK, json: parameters)
    }
}
