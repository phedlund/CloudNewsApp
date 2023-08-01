//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

//import Combine
import Foundation
import Observation

@Observable
final class Node: Identifiable {
    var unreadCount = 0
    var errorCount = 0
    var title = ""

    let id: String

//    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
//    private let didChangePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: NewsData.shared.container.viewContext).eraseToAnyPublisher()

    private(set) var isExpanded = false
    private(set) var nodeType = NodeType.empty
    private(set) var children: [Node]? = nil

//    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(.empty, id: Constants.allNodeGuid, isExpanded: false)
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.init(nodeType, children: nil, id: id, isExpanded: isExpanded)
    }

    init(_ nodeType: NodeType, children: [Node]? = nil, id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.id = id
        self.isExpanded = isExpanded
        self.title = nodeTitle()
        self.children = children

//        changePublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] changes in
//                guard let self else { return }
//                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
//                for change in changes {
//                    if change.nodeType == self.nodeType {
//                        switch change.nodeType {
//                        case .empty, .all, .starred:
//                            break
//                        case .folder(let id):
//                            if let folder = CDFolder.folder(id: id) {
//                                self.title = folder.name ?? "Untitled"
//                                self.isExpanded = folder.opened
//                            }
//                        case .feed(let id):
//                            if let feed = CDFeed.feed(id: id) {
//                                self.title = feed.title ?? "Untitled"
//                                self.errorCount = Int(feed.updateErrorCount)
//                            }
//                        }
//                    }
//                }
//            }
//            .store(in: &cancellables)
//
//        didChangePublisher
//            .receive(on: DispatchQueue.main)
//            .sink { [weak self] _ in
//                guard let self else { return }
//                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
//            }
//            .store(in: &cancellables)

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
            return Folder.folder(id: id)?.name ?? "Untitled Folder"
        case .feed(let id):
            return Feed.feed(id: id)?.title ?? "Untitled Feed"
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
