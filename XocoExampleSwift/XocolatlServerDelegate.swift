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
        let serverConfig = ServerConfiguration(requestDelegate: self, certificatePath: path, certificatePassword: "alderaan19")
        return try! Server(configuration: serverConfig)
    }()

    func startServer() {
        try! server.start(listeningAtPort: 3000)
    }
}

//MARK: - Responding to Requests
extension XocolatlServerDelegate : RequestDelegate {

    func reply(toRequest request: Request) -> HTTPResponsive {

        // Could we parse the request?
        guard case .success = request.status else {
            return GenericResponse(.GenericClientError)
        }

        // We could. Respond.
        // Ask our router for the response to this request.
        return GenericResponse(.OK)
    }
}
