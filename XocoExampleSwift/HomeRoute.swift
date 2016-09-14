//
//  HomeRoute.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/14/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

class HomeRoute : Routable {

    var path: String { return "/" }
    var method: Method { return .GET }

    func handle(_ route: Request, parameters: [String : String]) -> HTTPResponsive {
        return try! JSONResponse(code: .OK, json: [
            "server": "Xocolatl",
            "version": "0.1a"
            ])
    }

    func validateInputs(_ route: Request, parameters: [String : String]) -> HTTPResponsive? { return nil }
}
