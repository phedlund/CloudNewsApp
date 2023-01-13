//
//  NodeRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/30/22.
//

import Combine
import CoreData
import Foundation

class NodeRepository: ObservableObject {
    @Published var predicate = NSPredicate(value: false)
    @Published var currentNode: Node.ID? {
        didSet {
            preferences.selectedNode = currentNode ?? AllNodeGuid
            currentItem = nil
            updatePredicate()
        }
    }
    @Published var currentItem: NSManagedObjectID?

    private var preferences = Preferences()
    private var cancellables = Set<AnyCancellable>()

    init() {
        currentNode = preferences.selectedNode
        preferences.$hideRead.sink { [weak self] _ in
            guard let self else { return }
            self.updatePredicate()
        }
        .store(in: &cancellables)

        updatePredicate()
    }

    private func updatePredicate() {
        guard let currentNode else { return }
        print("Setting predicate")
        DispatchQueue.main.async {
            var predicate1 = NSPredicate(value: true)
            if self.preferences.hideRead {
                predicate1 = NSPredicate(format: "unread == true")
            }
            switch NodeType.fromString(typeString: currentNode) {
            case .empty:
                self.predicate = NSPredicate(value: false)
            case .all:
                self.predicate = NSPredicate(value: true)
            case .starred:
                self.predicate = NSPredicate(format: "starred == true")
            case .folder(id:  let id):
                if let feedIds = CDFeed.idsInFolder(folder: id) {
                    let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
                    self.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
                }
            case .feed(id: let id):
                let predicate2 = NSPredicate(format: "feedId == %d", id)
                self.predicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
            }
        }
    }
}
