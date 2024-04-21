//
//  MarkReadButton.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/19/23.
//

import SwiftData
import SwiftUI

struct MarkReadButton: View {
    @Environment(FeedModel.self) private var feedModel
    private let node: Node

    @State private var isDisabled = true

    @Query private var items: [Item]

    init(node: Node) {
        self.node = node
        var predicate = #Predicate<Item> { _ in return false }
        switch node.nodeType {
        case .empty:
            break
        case .all:
            predicate = #Predicate<Item> { $0.unread == true }
        case .starred:
            predicate = #Predicate<Item> { $0.starred == true }

        case .feed(let id):
            predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
        case .folder(let id):
            if let feedIds = feedModel.modelContext.feedIdsInFolder(folder: id) {
                predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
            }
        }
        _items = Query(filter: predicate)
    }

    var body: some View {
        Button {
            node.markRead()
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(items.count == 0)
    }

}

//#Preview {
//    MarkReadButton()
//}
