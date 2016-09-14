//
//  Router+RequestDelegate.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/13/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

//MARK: - Responding to Requests
extension Router : RequestDelegate {

    func reply(toRequest request: Request) -> HTTPResponsive {

        // Could we parse the request?
        guard case .success = request.status else {
            return GenericResponse(.GenericClientError)
        }

        // Okay, who's responsible for this request?
        guard let responsibleRoute = route(forRequest: request) else {
            return GenericResponse(.GenericServerError)
        }

        return responsibleRoute.handle(request)
    }
}
