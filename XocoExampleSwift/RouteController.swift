//
//  RouteController.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/14/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Foundation
import AppKit

class RouteController : NSViewController {

    var routes = [Routable]()

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var pathTextField: NSTextField!
    @IBOutlet var responseField: NSTextView!
    @IBOutlet var methodPopupButton: NSPopUpButton! {
        didSet {
            methodPopupButton.pullsDown = true
            methodPopupButton.removeAllItems()
            methodPopupButton.addItems(withTitles: ["GET"])
            methodPopupButton.selectItem(at: 0)
        }
    }

    @IBAction func addRoute(sender: AnyObject) {
        guard let selectedMethodString = methodPopupButton.selectedItem?.title,
            let response = responseField.string else { return }
        addRoute(path: pathTextField.stringValue, method: Method(value: selectedMethodString), response: response)
    }

    func addRoute(path: String, method: Method, response: String) {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }

        let newRoute = JSONRoute(path: path, method: method, response: response)!
        delegate.serverDelegate.addRoute(newRoute)
        routes.append(newRoute)
        pathTextField.stringValue = ""
        tableView.reloadData()
    }
}

extension RouteController : NSTableViewDataSource {

        func numberOfRows(in tableView: NSTableView) -> Int {
            return routes.count
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            let route = routes[row]
    
            let cellContentString: String
            if tableColumn == tableView.tableColumns[0] {
                cellContentString = route.method.rawValue
            } else {
                cellContentString = route.path
            }
    
            return cellContentString
        }
}
