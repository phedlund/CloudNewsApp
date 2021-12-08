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
    @Published var unreadCount = ""
    @Published var title = ""
    @Published var icon = UIImage()
    @Published var items = [ArticleModel]()

    let id: String
    private let itemPublisher = ItemStorage.shared.items.eraseToAnyPublisher()
    private let preferences = Preferences()

    fileprivate(set) var isExpanded = false
    private(set) var nodeType: NodeType
    private(set) var children = [Node]()

    private var cancellables = Set<AnyCancellable>()
    private var hideRead = false
    private var sortOldestFirst = false

    convenience init() {
        self.init(.all, id: AllNodeGuid, isExpanded: false)
        title = "All Articles"
    }

    convenience init(_ nodeType: NodeType, id: String, isExpanded: Bool = false) {
        self.init(nodeType, children: [], id: id, isExpanded: isExpanded)
    }

    init(_ nodeType: NodeType, children: [Node], id: String, isExpanded: Bool) {
        self.nodeType = nodeType
        self.children = children
        self.id = id
        self.isExpanded = isExpanded
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
                print("Updating \(self.nodeType)")
                self.items = items
                    .sorted(by: { self.sortOldestFirst ? $1.id > $0.id : $0.id > $1.id } )
                    .map { ArticleModel(item: $0) }
                let count = CDItem.unreadCount(nodeType: self.nodeType)
                self.unreadCount = count > 0 ? "\(count)" : ""
            }
            .store(in: &cancellables)

        retrieveIcon()
    }

    func configureItems() {
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
