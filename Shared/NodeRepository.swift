//
//  NodeRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/30/22.
//

import Foundation

class NodeRepository: ObservableObject {
    @Published var predicate = NSPredicate(value: false)
    @Published var currentNode: Node.ID? {
        didSet {
            preferences.selectedNode = currentNode ?? EmptyNodeGuid
            updatePredicate()
        }
    }

    private var preferences = Preferences()

    init() {
        currentNode = preferences.selectedNode
        updatePredicate()
    }

    private func updatePredicate() {
        print("Setting predicate")
        var predicate1 = NSPredicate(value: true)
        if preferences.hideRead {
            predicate1 = NSPredicate(format: "unread == true")
        }
        switch NodeType.fromString(typeString: currentNode ?? EmptyNodeGuid) {
        case .empty:
            predicate = NSPredicate(value: false)
        case .all:
            predicate = NSPredicate(value: true)
        case .starred:
            predicate = NSPredicate(format: "starred == true")
        case .folder(id:  let id):
            if let feedIds = CDFeed.idsInFolder(folder: id) {
                let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
                predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
            }
        case .feed(id: let id):
            let predicate2 = NSPredicate(format: "feedId == %d", id)
            predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
        }
    }
}
