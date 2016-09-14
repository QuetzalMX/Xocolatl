//
//  Route.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/13/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

/// Consider making this throwable.
protocol Routable {

    var path: String { get }
    var method: Method { get }

    func handle(_ route: Request) -> HTTPResponsive
    func validateInputs(_ route: Request) throws
}
