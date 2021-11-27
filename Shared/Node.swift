//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import UIKit
import CloudKit

let AllNodeGuid = "72137d96-4ef2-11ec-81d3-0242ac130003"
let StarNodeGuid = "967917a4-4ef2-11ec-81d3-0242ac130003"

final class Node: Identifiable, ObservableObject {
    @Published var unreadCount = ""
    @Published var title = ""
    @Published var icon = UIImage()

    let id: String

    fileprivate(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children = [Node]()

    init() {
        nodeType = .all
        title = "All Articles"
        id = AllNodeGuid
        retrieveIcon()
    }

    init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.nodeType = nodeType
        self.id = id
        self.isExpanded = isExpanded
        retrieveIcon()
    }

    init(_ nodeType: NodeType, children: [Node], id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.children = children
        self.id = id
        self.isExpanded = isExpanded
        retrieveIcon()
    }

    func updateExpanded(_ isExpanded: Bool) {
        switch nodeType {
        case .folder(let id):
            Task {
                self.isExpanded = isExpanded
                try? await CDFolder.markExpanded(folderId: id, state: isExpanded)
            }
        case _: ()
        }
    }

    private func retrieveIcon() {
        var result = UIImage(named: "favicon") ?? UIImage()

        switch nodeType {
        case .all:
            break
        case .starred:
            result = UIImage(systemName: "star.fill") ?? result
        case .folder( _):
            result = UIImage(systemName: "folder") ?? result
        case .feed(let id):
            if let feed = CDFeed.feed(id: id) {
                if let data = feed.favicon {
                    result = UIImage(data: data) ?? UIImage()
                }
            }
        }
        icon = result
    }

}

extension Node: Equatable {
    static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Node: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
