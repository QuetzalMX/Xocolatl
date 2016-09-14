//
//  Router.swift
//  Xocoexample
//
//  Created by Fernando Olivares on 9/9/16.
//  Copyright © 2016 Quetzal. All rights reserved.

import Foundation

/// Once a Request is ready to be processed (either parsed or failed parsing), it's passed to us for handling.
class Router {

    fileprivate var routes: [NSRegularExpression: (route: Routable, parameters: [String])] = [:]

    private lazy var server: Server = {
        let path = Bundle.main.path(forResource: "dev.quetzal.io", ofType: ".p12")!
        let serverConfig = ServerConfiguration(requestDelegate: self, certificatePath: path, certificatePassword: "alderaan19")
        return try! Server(configuration: serverConfig)
    }()

    func startServer() throws {
        try server.start(listeningAtPort: 3000)
    }
}

extension Router {

    func route(forRequest request: Request) -> Routable? {
        // Do we have a route that can handle it?
        let filteredRoutes = routes.filter { routeRegex, routeInfo -> Bool in

            // Can this route handle that method?
            guard routeInfo.route.method == request.method else {
                return false
            }

            // FIXME: Searching for the first match is unlikely to be enough, as it could be possible that two routes share the same first parameter?
            let requestPath: NSString = request.url!.relativePath as NSString
            guard let _ = routeRegex.firstMatch(in: requestPath as String, range: NSRange(location: 0, length: requestPath.length)) else {
                //Note: (FO) A regex will not return a result if there are no values in any captured group.
                //This does not mean that the responder is not responsible, it only means that there were no arguments passed when they were probably expected.
                //Perhaps it's the path without any matching capture groups?
                //e.g. /api/teams/:id
                //being called using
                // /api/teams/
                // I'm assuming we're not responsible of sanitizing inputs, so if the path is contained in the responder's path for this method, let it through.
                return requestPath.contains(routeInfo.route.path)
            }

            return true
        }

        guard !filteredRoutes.isEmpty else {
            return nil
        }

        assert(filteredRoutes.count == 1, "There's two responsible routes for this request: \(request)")

        return filteredRoutes.first!.value.route
    }

    func addRoute(_ route: Routable) {
        let routeRegex = regex(fromPath: route.path as NSString)
        routes[routeRegex.regex] = (route, routeRegex.capturedGroupsNames)
    }

    /// Converts the given path to a regex.
    /// The reason we use an NSString instead of a String is that NSRegularExpresion's enumerateMatches(in:range:length) still uses ranges.
    /// Going back and forth using NSRange and Range<String.Int> isn't really fun.
    ///
    /// FIXME: Need to expand on this: passing a regex, using *, parameters with :
    ///
    /// - parameter providedPath: the provided path
    ///
    /// - returns: the regex from that path
    private func regex(fromPath providedPath: NSString) -> (regex: NSRegularExpression, capturedGroupsNames: [String]) {

        // If the user provided a custom regex, just let them be.
        let isCustomRegEx = providedPath.length > 1 && providedPath.substring(to: 1) == "{"
        guard !isCustomRegEx else {
            let customRegexString = providedPath.substring(with: NSRange(location: 1, length: providedPath.length - 2))
            return (try! NSRegularExpression(pattern: customRegexString, options: .caseInsensitive), [])
        }

        // Make sure our path has a '/' as a first character.
        var preparedPath = providedPath as NSString
        if preparedPath.substring(to: 1) != "/" {
            preparedPath = "/\(preparedPath)" as NSString
        }

        // Escape regex characters.
        let fullPathRegex = try! NSRegularExpression(pattern: "[.+()]")
        let parsedPath = fullPathRegex.stringByReplacingMatches(in: preparedPath as String,
                                                                range: NSRange(location: 0, length: preparedPath.length),
                                                                withTemplate: "\\\\$0") as NSString

        // Parse any :parameters and * in the path
        let parameterRegex = try! NSRegularExpression(pattern: "(:(\\w+)|\\*)")
        let finalRegexPath = parsedPath.mutableCopy() as! NSMutableString

        var diff = 0
        var capturedGroupsNames = [String]()
        parameterRegex.enumerateMatches(in: parsedPath as String, range: NSRange(location: 0, length: parsedPath.length)) { result, flags, stop in

            guard let existingResult = result else { return }

            var replacementRange = NSRange(location: diff + existingResult.range.location, length: existingResult.range.length)
            var replacement: NSString = "(.*?)" as NSString

            let captured = parsedPath.substring(with: existingResult.range)
            if captured == "*" {
                capturedGroupsNames.append("wildcards")
                replacement = "(.*?)"
            } else {
                let capturedGroupName = parsedPath.substring(with: existingResult.rangeAt(2))
                capturedGroupsNames.append(capturedGroupName)
                replacement = "[/]?([^/]+)"
            }

            // Check whether we have to remove the slash.
            // The reason we do this is that whenever we have a path like:
            //  /api/teams/:id
            // and we receive a request like
            //  /api/teams
            // the regex does not match because we have included a /
            // so comparisons fails.

            var fixPathIfDirectory: NSString = finalRegexPath.replacingOccurrences(of: captured, with: "") as NSString
            if fixPathIfDirectory.hasSuffix("/") {
                fixPathIfDirectory = fixPathIfDirectory.substring(to: fixPathIfDirectory.length - 1) as NSString
                fixPathIfDirectory = fixPathIfDirectory.appending(captured) as NSString
                replacementRange = fixPathIfDirectory.range(of: captured)

                //Since we removed one character, we add one to the length of the range.
                replacementRange.length = replacementRange.length + 1
            }
            
            finalRegexPath.replaceCharacters(in: replacementRange, with: replacement as String)
            diff = diff + replacement.length - existingResult.range.length
        }
        
        return (try! NSRegularExpression(pattern: "^\(finalRegexPath)$"), capturedGroupsNames)
    }
}
