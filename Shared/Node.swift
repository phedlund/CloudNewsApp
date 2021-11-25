//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import UIKit

final class Node: Identifiable, ObservableObject {
    @Published var unreadCount = ""
    @Published var title = ""
    @Published var icon = UIImage()

    fileprivate(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children = [Node]()

    init() {
        nodeType = .all
        title = "All Articles"
        retrieveIcon()
    }

    init(_ nodeType: NodeType, isExpanded: Bool = false) {
        self.nodeType = nodeType
        self.isExpanded = isExpanded
        retrieveIcon()
    }

    init(_ nodeType: NodeType, children: [Node], isExpanded: Bool) {
        self.nodeType = nodeType
        self.children = children
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
        return lhs.nodeType == rhs.nodeType
    }
}
