//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import CloudKit
import Combine
import Kingfisher

let EmptyNodeGuid = "0044f316-8559-4aea-b5fe-41084135730b"
let AllNodeGuid = "72137d96-4ef2-11ec-81d3-0242ac130003"
let StarNodeGuid = "967917a4-4ef2-11ec-81d3-0242ac130003"

final class Node: Identifiable, ObservableObject {
    @Published var unreadCount = 0
    @Published var errorCount = 0
    @Published var title = ""

    let id: String

    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()

    private(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children: [Node]?

    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(.all, id: AllNodeGuid, isExpanded: false)
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.init(nodeType, children: nil, id: id, isExpanded: isExpanded)
    }

    init(_ nodeType: NodeType, children: [Node]? = nil, id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.children = children
        self.id = id
        self.isExpanded = isExpanded
        self.title = nodeTitle()

        changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changes in
                guard let self else { return }
                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
                for change in changes {
                    if change.nodeType == self.nodeType {
                        switch change.nodeType {
                        case .empty, .all, .starred:
                            break
                        case .folder(let id):
                            if let folder = CDFolder.folder(id: id) {
                                self.title = folder.name ?? "Untitled"
                                self.isExpanded = folder.opened
                            }
                        case .feed(let id):
                            if let feed = CDFeed.feed(id: id) {
                                self.title = feed.title ?? "Untitled"
                                self.errorCount = Int(feed.updateErrorCount)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func nodeTitle() -> String {
        switch nodeType {
        case .empty:
            return ""
        case .all:
            return "All Articles"
        case .starred:
            return "Starred Articles"
        case .folder(let id):
            return CDFolder.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return CDFeed.feed(id: id)?.title ?? "Untitled Feed"
        }
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
