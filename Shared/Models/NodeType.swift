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
