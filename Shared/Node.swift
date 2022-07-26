//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import CloudKit
import Combine

let EmptyNodeGuid = "0044f316-8559-4aea-b5fe-41084135730b"
let AllNodeGuid = "72137d96-4ef2-11ec-81d3-0242ac130003"
let StarNodeGuid = "967917a4-4ef2-11ec-81d3-0242ac130003"

final class Node: Identifiable, ObservableObject {
    @Published var unreadCount = 0
    @Published var errorCount = 0
    @Published var title = ""
    @Published var icon = SystemImage()
    @Published var items = [ArticleModel]()
    @Published var currentItem: ArticleModel?

    func item(for id: ArticleModel.ID) -> ArticleModel? {
        items.first(where: { $0.id == id} )
    }

    var id: String
    private let itemPublisher = ItemStorage.shared.items.eraseToAnyPublisher()
    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()

    fileprivate(set) var isExpanded = false
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
        self.icon = nodeIcon()

        itemPublisher
            .receive(on: DispatchQueue.main)
            .sink { items in
                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
                switch nodeType {
                case .empty:
                    break
                case .all:
                    self.items = items.map( { ArticleModel(item: $0) } )
                case .starred:
                    self.items = items
                        .filter( { $0.starred == true } )
                        .map( { ArticleModel(item: $0) } )
                case .folder(let id):
                    if let feedIds = CDFeed.idsInFolder(folder: id) {
                        self.items = items
                            .filter( { feedIds.contains($0.feedId) } )
                            .map( { ArticleModel(item: $0) } )
                    } else {
                        self.items = []
                    }
                case .feed(let id):
                    self.items = items
                        .filter( { $0.feedId == id } )
                        .map( { ArticleModel(item: $0) } )
                }
            }
            .store(in: &cancellables)

        changePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changes in
                guard let self = self else { return }
                for change in changes {
                    if change.nodeType == self.nodeType {
                        self.unreadCount = CDItem.unreadCount(nodeType: change.nodeType)
                        switch change.nodeType {
                        case .empty, .all:
                            break
                        case .starred:
                            if let starredItems = CDItem.starredItems() {
                                self.items = starredItems.map( { ArticleModel(item: $0) } )
                            } else {
                                self.items.removeAll()
                            }
                        case .folder(let id):
                            if let folder = CDFolder.folder(id: id) {
                                self.title = folder.name ?? "Untitled"
                                self.isExpanded = folder.expanded
                            }
                        case .feed(let id):
                            if let feed = CDFeed.feed(id: id) {
                                self.title = feed.title ?? "Untitled"
                                self.icon = self.nodeIcon()
                                self.errorCount = Int(feed.updateErrorCount)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func updateCurrentItem(_ current: ArticleModel?) {
        currentItem = current
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

    private func nodeIcon() -> SystemImage {
        switch nodeType {
        case .empty, .all:
            return SystemImage(named: "rss")!
        case .starred:
            return SystemImage(symbolName: "star.fill")!
        case .folder( _):
            return SystemImage(symbolName: "folder")!
        case .feed(let id):
            if let feed = CDFeed.feed(id: id), let data = feed.favicon {
                return SystemImage(data: data) ?? SystemImage(named: "rss") ?? SystemImage()
            } else {
                return SystemImage(named: "rss")!
            }
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
