//
//  EchoRoute.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/14/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

class EchoeRoute : Routable {

    var path: String { return "/:greeting/team/:person" }
    var method: Method { return .GET }

    func handle(_ route: Request, parameters: [String : String]) -> HTTPResponsive {
        let jsonResponse = [parameters["greeting"]! : parameters["person"]!]
        return try! JSONResponse(code: .OK,
                                 json: jsonResponse)
    }
}
