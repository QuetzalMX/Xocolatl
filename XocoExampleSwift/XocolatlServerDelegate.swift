//
//  Router.swift
//  Xocoexample
//
//  Created by Fernando Olivares on 9/9/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

/// This class will eventually migrate to be the router.
class XocolatlServerDelegate {

    private lazy var server: Server = {
        let path = Bundle.main.path(forResource: "dev.quetzal.io", ofType: ".p12")!
        return try! Server(certificatePath: path, certificatePassword: "alderaan19")
    }()

    func startServer() {
        try! server.start(responseDelegate: self)
    }
}

extension XocolatlServerDelegate : ServerDelegate {

    func respond(_ request: RequestParser) -> Response? {
        return GenericResponse(code: .OK, body: request.data.body.content)
    }
}
