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

extension NodeType: CustomStringConvertible {
    var description: String {
        switch self {
        case .empty:
            return ""
        case .all:
            return "aaaa"
        case .starred:
            return "bbbb"
        case .folder(id: let id):
            return "cccc_\(String(format: "%03d", id))"
        case .feed(id: let id):
            return "dddd_\(String(format: "%03d", id))"
        }
    }
    
}

extension NodeType {

    var asData: Data {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            return Data()
        }
    }

    static func fromData(_ data: Data) -> NodeType? {
        do {
            return try JSONDecoder().decode(NodeType.self, from: data)
        } catch {
            return nil
        }
    }

}
