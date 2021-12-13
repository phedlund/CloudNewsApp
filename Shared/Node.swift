//
//  Node.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import UIKit
import CloudKit
import Combine

let AllNodeGuid = "72137d96-4ef2-11ec-81d3-0242ac130003"
let StarNodeGuid = "967917a4-4ef2-11ec-81d3-0242ac130003"

final class Node: Identifiable, ObservableObject {
    @Published var unreadCount = 0
    @Published var title = ""
    @Published var icon = UIImage()
    @Published var items = [ArticleModel]()

    let id: String
    private let itemPublisher = ItemStorage.shared.items.eraseToAnyPublisher()
    private let changePublisher = ItemStorage.shared.changes.eraseToAnyPublisher()
    private let preferences = Preferences()

    fileprivate(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children = [Node]()

    private var cancellables = Set<AnyCancellable>()
    private var hideRead = false
    private var sortOldestFirst = false

    convenience init() {
        self.init(.all, id: AllNodeGuid, isExpanded: false)
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.init(nodeType, children: [], id: id, isExpanded: isExpanded)
    }

    init(_ nodeType: NodeType, children: [Node], id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.children = children
        self.id = id
        self.isExpanded = isExpanded
        self.title = nodeTitle(nodeType)
        preferences.$hideRead.sink { [weak self] hideRead in
            self?.hideRead = hideRead
            self?.configureItems()
        }
        .store(in: &cancellables)

        preferences.$sortOldestFirst.sink { [weak self] sortOldestFirst in
            self?.sortOldestFirst = sortOldestFirst
            self?.configureItems()
        }
        .store(in: &cancellables)

        itemPublisher
            .receive(on: DispatchQueue.main)
            .map { rawItems in
                rawItems.filter { [weak self] item in
                    guard let self = self else { return false }
                    switch self.nodeType {
                    case .all:
                        return self.hideRead ? item.unread : true
                    case .starred:
                        return item.starred
                    case .folder(let id):
                        if let feedIds = CDFeed.idsInFolder(folder: id) {
                            let check1 = feedIds.contains(item.feedId)
                            let check2 = self.hideRead ? item.unread : true
                            return check1 && check2
                        }
                    case .feed(let id):
                        let check1 = item.feedId == id
                        let check2 = self.hideRead ? item.unread : true
                        return check1 && check2
                    }
                    return false
                }
            }
            .sink { items in
                print("Updating \(self.nodeType) with \(items.count) items")
                self.items = items
                    .sorted(by: { self.sortOldestFirst ? $1.id > $0.id : $0.id > $1.id } )
                    .map { ArticleModel(item: $0) }
                self.unreadCount = CDItem.unreadCount(nodeType: self.nodeType)
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
                        case .all:
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
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        retrieveIcon()
    }

    func configureItems() {
    }

    private func nodeTitle(_ nodeType: NodeType) -> String {
        switch nodeType {
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

    private func retrieveIcon() {
        switch nodeType {
        case .all:
            icon = UIImage(named: "rss")!
        case .starred:
            icon = UIImage(systemName: "star.fill")!
        case .folder( _):
            icon = UIImage(systemName: "folder")!
        case .feed(let id):
            if let feed = CDFeed.feed(id: id), let data = feed.favicon {
                icon = UIImage(data: data) ?? UIImage(named: "rss") ?? UIImage()
            } else {
                icon = UIImage(named: "rss")!
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
