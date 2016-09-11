//
//  AppDelegate.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/9/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    let serverDelegate = XocolatlServerDelegate()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        serverDelegate.startServer()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
