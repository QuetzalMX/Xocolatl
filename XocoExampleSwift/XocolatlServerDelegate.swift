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

//MARK: - Responding to Requests
extension XocolatlServerDelegate : ConnectionHandlerDelegate {

    // Result
    public func reply(request: Request, fromHandler handler: ConnectionHandler) {

        NotificationCenter.default.post(name: Notification.Name("ReceivedRequest"),
                                        object: request)

        // Could we parse the request?
        guard case .success = handler.status else {
            return
        }

        // We could. Respond.
//        guard let response = responseDelegate?.respond(request) else {
//            // Our delegate won't respond. 500.
//            let invalidRequest = GenericResponse(code: .GenericServerError, body: nil)
//            handler.respond(with: invalidRequest)
//            return
//        }

//        handler.respond(with: response)
    }
}
