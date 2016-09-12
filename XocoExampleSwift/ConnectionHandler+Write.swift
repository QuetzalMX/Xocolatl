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
        data = Request()
        headerLines = 0
        contentLength = 0
        contentLengthReceived = 0
        chunkSize = 0
        chunkSizeReceived = 0

    }
}
