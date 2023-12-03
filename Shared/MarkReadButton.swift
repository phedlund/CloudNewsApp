//
//  MarkReadButton.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/19/23.
//

import SwiftData
import SwiftUI

struct MarkReadButton: View {
    @Environment(\.feedModel) private var feedModel

    @State private var unreadItems = [Item]()

    var body: some View {
        Button {
            Task {
                if let container = NewsData.shared.container {
                    do {
                        if !unreadItems.isEmpty {
                            for item in unreadItems {
                                item.unread = false
                            }
                            try container.mainContext.save()
                            try await NewsManager.shared.markRead(items: unreadItems, unread: false)
                            updateUnreadItems(node: feedModel.currentNode)
                        }
                    } catch {
                        //
                    }
                }
            }
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [.control])
        .onChange(of: feedModel.currentNode, initial: true, { oldValue, newValue in
            updateUnreadItems(node: newValue)
        })
        .disabled(unreadItems.isEmpty)
    }

    @MainActor
    private func updateUnreadItems(node: Node) {
        var unreadItemsDescriptor = FetchDescriptor<Item>(predicate: #Predicate { _ in false } )

        switch node.nodeType {
        case .empty, .all, .starred:
            break
        case .folder(let id):
            if let feedIds = Feed.idsInFolder(folder: id) {
                unreadItemsDescriptor = FetchDescriptor<Item>(predicate: #Predicate { item in
                    feedIds.contains(item.feedId) &&
                    item.unread == true
                })
            }
        case .feed(let id):
            unreadItemsDescriptor = FetchDescriptor<Item>(predicate: #Predicate { item in
                item.feedId == id &&
                item.unread == true
            })
        }
        if let container = NewsData.shared.container {
            do {
                unreadItems = try container.mainContext.fetch(unreadItemsDescriptor)
            } catch {
                //
            }
        }
    }
}

#Preview {
    MarkReadButton()
}
