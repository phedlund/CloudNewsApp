//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Kingfisher
import SwiftUI

struct ArticlesFetchView<Content: View>: View {
    @FetchRequest var items: FetchedResults<CDItem>
    let content: (FetchedResults<CDItem>) -> Content

    private var predicate: NSPredicate
    private var model: FeedModel
    private var nodeId: Node.ID
    private var node = Node(.empty, id: EmptyNodeGuid)

    init(nodeId: Node.ID, model: FeedModel, hideRead: Bool, sortOldestFirst: Bool, @ViewBuilder content: @escaping (FetchedResults<CDItem>) -> Content) {
        let _ = print(nodeId)
        self.model = model
        self.nodeId = nodeId
        node = model.node(for: nodeId) ?? Node(.empty, id: EmptyNodeGuid)
        var predicate1 = NSPredicate(value: true)
        if hideRead {
            predicate1 = NSPredicate(format: "unread == true")
        }
        predicate = NSPredicate(value: true)

        switch node.nodeType {
        case .empty, .all:
            predicate = predicate1
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

        self._items = FetchRequest(sortDescriptors: sortOldestFirst ? ItemSort.oldestFirst.descriptors : ItemSort.default.descriptors,
                                         predicate: predicate)
        self.content = content
    }

    var body: some View {
        self.content(items)
            .navigationTitle(node.title)
            .task(id: nodeId) {
                do {
                    let itemsWithoutImageLink = items.filter({ $0.imageLink == nil || $0.imageLink == "data:null" })
                    if !itemsWithoutImageLink.isEmpty {
                        try await ItemImageFetcher.shared.itemURLs(itemsWithoutImageLink)
                        let urls = items.compactMap({ $0.imageUrl as URL? })
                        ImagePrefetcher(urls: urls).start()
                    }
                } catch  { }
            }
            .onChange(of: nodeId) { _ in
                print("Node id changed")
            }
    }
}
