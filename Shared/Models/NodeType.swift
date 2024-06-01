//
//  NodeType.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018-2024 Peter Hedlund. All rights reserved.
//

import Foundation

enum NodeType: Equatable, Hashable, Codable {
    case empty
    case all
    case starred
    case folder(id: Int64)
    case feed(id: Int64)
}

extension NodeType {

    static func fromString(typeString: String) -> NodeType {
        switch typeString {
        case Constants.allNodeGuid:
            return .all
        case Constants.starNodeGuid:
            return .starred
        case Constants.emptyNodeGuid:
            return .empty
        case _ where typeString.hasPrefix("cccc"):
            if let index = typeString.lastIndex(of: "_") {
                let idString = String(typeString.suffix(from: typeString.index(index, offsetBy: 1)))
                let myId = Int64(idString)
                return .folder(id: myId ?? 0)
            } else {
                return .empty
            }
        case _ where typeString.hasPrefix("dddd"):
            if let index = typeString.lastIndex(of: "_") {
                let idString = String(typeString.suffix(from: typeString.index(index, offsetBy: 1)))
                let myId = Int64(idString)
                return .feed(id: myId ?? 0)
            } else {
                return .empty
            }
        default:
            return .empty
        }
    }

}
