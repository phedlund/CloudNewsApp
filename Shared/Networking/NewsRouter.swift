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
        let username = "appstore" //KeychainStore().username
        let password = "reviewer701" //KeychainStore().password
        return Data("\(username):\(password)".utf8).base64EncodedString()
    }

    private var basicAuthHeader: String {
        return "Basic \(credentials)"
    }

    
    // MARK: URLRequestConvertible
    
    func urlRequest() throws -> URLRequest {
        @AppStorage(SettingKeys.server) var server: String = ""

        server = "https://peter.hedlund.dev"
        let baseURLString = "\(server)/apps/news/api/v1-2"
        let url = URL(string: baseURLString)! //FIX
      
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue(basicAuthHeader, forHTTPHeaderField: "Authorization")
        urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Accept")

//        let queryItems = parameters.map {
//            return URLQueryItem(name: "\($0)", value: "\($1)")
//        }


/*

 For PUT requests
 //            if let body = (try? JSONSerialization.data(withJSONObject: parameters, options: [])) {
 //                urlRequest.httpBody = body
 //                urlRequest.setValue("no-cache", forHTTPHeaderField: "cache-control")
 //                urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Content-Type")


 var request = URLRequest(url: fullURL)
 request.httpMethod = "PUT"
 request.allHTTPHeaderFields = [
     "Content-Type": "application/json",
     "Accept": "application/json"
 ]


 let headers = [
            "content-type": "application/json",
            "cache-control": "no-cache",
            "postman-token": "121b2f04-d2a4-72b7-a93f-98e3383f9fa0"
        ]
 let parameters = [
            "username": "\(Username)",
            "password": "\(password)"
        ]

 if let postData = (try? JSONSerialization.data(withJSONObject: parameters, options: [])) {

        var request = NSMutableURLRequest(url: URL(string: "YOUR_URL_HERE")!,
                                              cachePolicy: .useProtocolCachePolicy,
                                              timeoutInterval: 10.0)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData

        let session = URLSession.shared

        let task = URLSession.shared.dataTask(with: request as URLRequest) {
               (data, response, error) -> Void in
                if (error != nil) {
                    print(error)
                } else {
                    DispatchQueue.main.async(execute: {

                      if let json = (try? JSONSerialization.jsonObject(with: data!, options: [])) as? NSDictionary
                        {
                            let success = json["status"] as? Int
                            let message = json["message"] as? String
                            // here you check your success code.
                            if (success == 1)
                            {
                                print(message)
                                let vc = UIActivityViewController(activityItems: [image],  applicationActivities: [])
                                 present(vc, animated: true)
                            }
                            else
                            {

                               // print(message)
                            }

                        }

                    })
                }
            }

            task.resume()
        }

 */



        switch self {
        case .folders, .feeds:
            break
//        case .addFeed(let url, let folder):
//            let parameters = ["url": url, "folder": folder] as [String : Any]
//            urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)

//        deleteFeed
//            moveFeed
//            renameFeed
//        markFeedRead
        
//        case .addFolder(let name):
//            let parameters = ["name": name]
//            urlRequest = try URLEncoding.default.encode(urlRequest, with: parsameters)
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
                print(urlRequest.url?.absoluteString)
            }
//
//        case .itemsRead(let parameters), .itemsStarred(let parameters), .itemsUnstarred(let parameters):
//            urlRequest = try JSONEncoding.default.encode(urlRequest, with: parameters)
//
        case .version:
            break
            
        default:
            break
        }
        
        return urlRequest
    }
}
