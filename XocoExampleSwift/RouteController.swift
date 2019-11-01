//
//  RouteController.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/14/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation
import AppKit

/// This class is a work in progress. It's here while I test how to best build a UI for macOS.
class RouteController : NSViewController {

    var requests = [(request: Request, response: HTTPResponsive)]()
    @IBOutlet var requestsTableView: NSTableView!

    var routes = [Routable]()
    @IBOutlet var routeTableView: NSTableView!
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

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateRequests),
                                               name: Notification.Name("Responded"),
                                               object: nil)
    }

    @IBAction func addRoute(sender: AnyObject) {
        guard let selectedMethodString = methodPopupButton.selectedItem?.title else { return }
        addRoute(path: pathTextField.stringValue, method: Method(value: selectedMethodString), response: responseField.string)
    }

    func addRoute(path: String, method: Method, response: String) {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }

        let newRoute = JSONRoute(path: path, method: method, response: response)!
        delegate.serverDelegate.addRoute(newRoute)
        routes.append(newRoute)
        pathTextField.stringValue = ""
        responseField.string = ""
        routeTableView.reloadData()
    }

	@objc func updateRequests(notification: Notification) {
        guard let notificationInfo = notification.object as? [Any],
            let request = notificationInfo[0] as? Request,
            let response = notificationInfo[1] as? HTTPResponsive else { return }

        requests.append((request: request, response: response))

        DispatchQueue.main.async {
            self.requestsTableView.reloadData()
        }
    }
}

extension RouteController : NSTableViewDataSource {

        func numberOfRows(in tableView: NSTableView) -> Int {

            switch tableView {

                case routeTableView: return routes.count
                case requestsTableView: return requests.count
                default: fatalError("Unregistered tableView")

            }
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {

            switch tableView {
                case routeTableView:
                    let route = routes[row]

                    let cellContentString: String
                    if tableColumn == tableView.tableColumns[0] {
                        cellContentString = route.method.rawValue
                    } else {
                        cellContentString = route.path
                    }
                    
                    return cellContentString

                case requestsTableView:
                    let request = requests[row].request
                    let response = requests[row].response

                    let cellContentString: String
                    if tableColumn == tableView.tableColumns[0] {
                        cellContentString = "\(response.statusCode.value)"
                    } else if tableColumn == tableView.tableColumns[1] {
                        cellContentString = request.method.rawValue
                    } else {
                        cellContentString = request.url!.path
                    }

                    return cellContentString

                default: fatalError("Unregistered tableView")
            }

        }
}
