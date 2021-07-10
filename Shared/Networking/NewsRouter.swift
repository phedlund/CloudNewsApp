//
//  NewsRouter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/20/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation
import KeychainAccess
import SwiftUI

public typealias ParameterDict = [String: Any]

enum UrlSessionMethod: String {
    case connect = "CONNECT"
    case delete = "DELETE"
    case get = "GET"
    case head = "HEAD"
    case options = "OPTIONS"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"
    case trace = "TRACE"
}

enum PBHError: Error {
    case networkError(String)
    case databaseError(String)
}

enum StatusRouter {
    case status

    static let applicationJson = "application/json"

    var method: UrlSessionMethod {
        switch self {
        case .status:
            return .get
        }
    }

    private var credentials: String {
        @KeychainStorage(StorageKeys.username) var username = ""
        @KeychainStorage(StorageKeys.password) var password = ""
        return Data("\(username):\(password)".utf8).base64EncodedString()
    }

    private var basicAuthHeader: String {
        return "Basic \(credentials)"
    }

    // MARK: URLRequestConvertible

    func urlRequest() throws -> URLRequest {
        @AppStorage(StorageKeys.server) var server: String = ""

//        server = "https://peter.hedlund.dev"

        switch self {
        case .status:
            if !server.isEmpty {
                var ocsUrlComponents = URLComponents()
                if let url = URL(string: server),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    ocsUrlComponents.scheme = components.scheme
                    ocsUrlComponents.host = components.host
                    ocsUrlComponents.port = components.port
                    var pathComponents = url.pathComponents

                    if pathComponents.last == "index.php" {
                        pathComponents = pathComponents.dropLast()
                    }
                    var newPath = pathComponents.joined(separator: "/")
                    if newPath.last == "/" {
                        newPath = String(newPath.dropLast())
                    }
                    if newPath.hasPrefix("//") {
                        newPath = String(newPath.dropFirst())
                    }
                    ocsUrlComponents.path = "\(newPath)/status.php"
                }
                let url = ocsUrlComponents.url ?? URL(string: server)

                var urlRequest = URLRequest(url: url ?? URL(fileURLWithPath: "/"))
                urlRequest.httpMethod = method.rawValue
                urlRequest.setValue(basicAuthHeader, forHTTPHeaderField: "Authorization")
                urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Accept")
                return urlRequest
            } else {
                throw PBHError.networkError("Missing server address")
            }
        }
    }
}

enum Router {

    case feeds
    case addFeed(url: String, folder: Int)
    case deleteFeed(id: Int)
    case moveFeed(id: Int, folder: Int)
    case renameFeed(id: Int, newName: String)
    case markFeedRead(id: Int, newestItemId: Int)

    case folders
    case addFolder(name: String)
    case deleteFolder(id: Int)
    case renameFolder(id: Int, newName: String)
    case markFolderRead(id: Int, newestItemId: Int)
    
    case items(parameters: ParameterDict)
    case updatedItems(parameters: ParameterDict)
    case itemRead(id: Int)
    case itemsRead(parameters: ParameterDict)
    case itemUnread(id: Int)
    case itemsUnread(parameters: ParameterDict)
    case itemStarred(id: Int, guid: String)
    case itemsStarred(parameters: ParameterDict)
    case itemUnstarred(id: Int, guid: String)
    case itemsUnstarred(parameters: ParameterDict)
    case allItemsRead

    case version

    static let applicationJson = "application/json"

    var method: UrlSessionMethod {
        switch self {
        case .feeds, .folders, .items, .updatedItems, .version:
            return .get
        case .addFeed, .addFolder:
            return .post
        case .deleteFeed, .deleteFolder:
            return .delete
        case .moveFeed, .renameFeed, .markFeedRead, .renameFolder, .markFolderRead, .itemRead, .itemsRead, .itemUnread, .itemsUnread, .itemStarred,. itemsStarred, .itemUnstarred, .itemsUnstarred, .allItemsRead:
            return .put
        }
    }
    
    var path: String {
        switch self {
        case .feeds:
            return "/feeds"
        case .addFeed(_ , _):
            return "/feeds"
        case .deleteFeed(let id):
            return "/feeds/\(id)"
        case .moveFeed(let id, _):
            return "/feeds/\(id)/move"
        case .renameFeed(let id, _):
            return "/feeds/\(id)/rename"
        case .markFeedRead(let id, _):
            return "/feeds/\(id)/read"

        case .folders:
            return "/folders"
        case .addFolder(_):
            return "/folders"
        case .deleteFolder(let id):
            return "/folders/\(id)"
        case .renameFolder(let id, _):
            return "/folders/\(id)"
        case .markFolderRead(let id, _):
            return "/folders/\(id)/read"

        case .items:
            return "/items"
        case .updatedItems(_):
            return "/items/updated"
        case .itemRead(let id):
            return "/item/\(id)/read"
        case .itemsRead(_):
            return "/items/read/multiple"
        case .itemUnread(let id):
            return "/item/\(id)/unread"
        case .itemsUnread(_):
            return "/items/unread/multiple"
        case .itemStarred(let id, let guid):
            return "/item/\(id)/\(guid)/star"
        case .itemsStarred(_):
            return "/items/star/multiple"
        case .itemUnstarred(let id, let guid):
            return "/item/\(id)/\(guid)/unstar"
        case .itemsUnstarred(_):
            return "/items/unstar/multiple"
        case .allItemsRead:
            return "/items/read"
        case .version:
            return "/version"
        }
    }

    private var credentials: String {
        @KeychainStorage(StorageKeys.username) var username: String = ""
        @KeychainStorage(StorageKeys.password) var password: String = ""
        return Data("\(username):\(password)".utf8).base64EncodedString()
    }

    private var basicAuthHeader: String {
        return "Basic \(credentials)"
    }

    
    // MARK: URLRequestConvertible
    
    func urlRequest() throws -> URLRequest {
        @AppStorage(StorageKeys.server) var server: String = ""

        let baseURLString = "\(server)/index.php/apps/news/api/v1-2"
        let url = URL(string: baseURLString)! //FIX
      
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.timeoutInterval = 20.0
        urlRequest.setValue(basicAuthHeader, forHTTPHeaderField: "Authorization")
        urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Accept")

        switch self {
        case .folders, .feeds:
            break
        case .addFeed(let url, let folder):
            let parameters = ["url": url, "folder": folder] as [String : Any]
            if let body = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                urlRequest.httpBody = body
//                urlRequest.setValue("no-cache", forHTTPHeaderField: "cache-control")
                urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Content-Type")
//                urlRequest.httpMethod = "PUT"
            }



//            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)

//        deleteFeed
//            moveFeed
//            renameFeed
//        markFeedRead
        
        case .addFolder(let name):
            let parameters = ["name": name]
            if let body = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                urlRequest.httpBody = body
                urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Content-Type")
            }
//            deleteFolder
//            renameFolder
//            markFolderRead
        
        case .items(let parameters), .updatedItems(let parameters):
            if let url = urlRequest.url {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let queryItems = parameters.map {
                    return URLQueryItem(name: "\($0)", value: "\($1)")
                }
                components?.queryItems = queryItems
                urlRequest.url = components?.url
            }

        case .itemsRead(let parameters), .itemsStarred(let parameters), .itemsUnstarred(let parameters):
            if let body = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                urlRequest.httpBody = body
                urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Content-Type")
            }

//            urlRequest = try JSONEncoding.default.encode(urlRequest, with: parameters)

        case .version:
            break
            
        default:
            break
        }
        
        return urlRequest
    }
}
