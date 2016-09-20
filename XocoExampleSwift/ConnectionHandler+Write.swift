//
//  ConnectionHandler+Write.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/11/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation

// MARK: - Write Delegation
extension ConnectionHandler : RequestSocketWriteDelegate {

    func didSendResponse() {
        request = Request()
        status = .listening
    }
}
