//
//  RequestTableView.swift
//  XocoExampleSwift
//
//  Created by Fernando Olivares on 9/10/16.
//  Copyright © 2016 Quetzal. All rights reserved.
//

import Cocoa

class RequestTableViewController: NSObject {

    var requests = [ConnectionHandler]()
    @IBOutlet weak var tableView: NSTableView!

    override init() {
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateTableView),
                                               name: ReceivedRequest,
                                               object: nil)
    }

    func updateTableView(notification: Notification) {
        guard let receivedRequest = notification.object as? ConnectionHandler else { return }

        DispatchQueue.main.async {
            self.requests.append(receivedRequest)
            self.tableView.reloadData()
        }
    }
}

extension RequestTableViewController : NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return requests.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let request = requests[row]

        let cellContentString: String
        if tableColumn == tableView.tableColumns[0] {
            cellContentString = request.data.method.rawValue
        } else {

            if let url = request.data.url?.relativeString {
                cellContentString = url
            } else {
                cellContentString = "??"
            }
        }

        return cellContentString
    }
}
