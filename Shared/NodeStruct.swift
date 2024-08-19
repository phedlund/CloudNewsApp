//
//  NodeStruct.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/18/24.
//

import Foundation

struct NodeStruct {
    var nodeName: String
    var isExpanded = false
    var nodeType: NodeType
    var title: String
    var isTopLevel: Bool
    var favIconURL: URL? = nil
    var childIds: [Int64]? = nil
    var errorCount: Int64 = 0
}
