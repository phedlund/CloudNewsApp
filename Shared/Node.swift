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
    @Published var favIconLink: String?
    @Published var items = [ArticleModel]()

    func item(for id: ArticleModel.ID) -> ArticleModel? {
        items.first(where: { $0.id == id} )
    }

    var id: String
    var cdItems = [CDItem]() {
        didSet {
            currentItem = 0
            canLoadMoreItems = cdItems.count > 0
            loadMoreContent()
        }
    }

    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()

    private(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children: [Node]?

    private var currentItem = 0
    private var canLoadMoreItems = false
    private var isLoadingItem = false
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
                guard let self = self else { return }
                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
                for change in changes {
                    if change.nodeType == self.nodeType {
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
                                self.favIconLink = feed.faviconLinkResolved
                                self.errorCount = Int(feed.updateErrorCount)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadMoreItemsIfNeeded(currentItem item: ArticleModel?) {
        guard item != nil else {
            loadMoreContent()
            return
        }

//        let thresholdIndex = items.index(items.endIndex, offsetBy: 0)
        if items.count < cdItems.count {
            loadMoreContent()
        }
    }

    private func loadMoreContent() {
        guard !isLoadingItem && canLoadMoreItems else {
            return
        }

        isLoadingItem = true
        let cdItem = cdItems[currentItem]
        let model = ArticleModel(item: cdItem)
        items.append(model)
        currentItem += 1
        isLoadingItem = false
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
