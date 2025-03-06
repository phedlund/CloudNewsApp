//
//  BadgeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/17/21.
//

import SwiftData
import SwiftUI

struct BadgeView: View {
    var node: Node
    @Environment(\.modelContext) private var modelContext

    @Query private var items: [Item]
    @Query private var feeds: [Feed]
    @Query private var folders: [Folder]

    private let errorCount = 0
    @State private var feed: Feed?
    private var feedId: Int64 = -1

    init(node: Node) {
        self.node = node
        var predicate = #Predicate<Item> { _ in return false }
        switch node.type {
        case .empty:
            break
        case .all:
            predicate = #Predicate<Item> { $0.unread == true }
        case .starred:
            predicate = #Predicate<Item> { $0.starred == true }
        case .feed(let id):
            feedId = id
            predicate = #Predicate<Item> { $0.feedId == id && $0.unread == true }
        case .folder( _):
            if let children = node.children {
                var feedIds = [Int64]()
                for child in children {
                    switch child.type {
                    case .empty, .all, .starred, .folder:
                        break
                    case .feed(let id):
                        feedIds.append(id)
                    }
                }
                predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
            }
        }
        _items = Query(filter: predicate)
    }

    @ViewBuilder
    var body: some View {
        HStack {
            if node.errorCount > 0 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            }
            if items.count > 0 {
                Text("\(items.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                        .fill(.gray))
            }
        }
        .task {
            feed = feeds.first(where: { $0.id == feedId })
        }
        .onChange(of: items.count, initial: true) { _, newValue in
            if node.type == .all {
#if os(macOS)
                NSApp.dockTile.badgeLabel = newValue > 0 ? "\(newValue)" : ""
#else
                Task {
                    do {
                        try await UNUserNotificationCenter.current().setBadgeCount(newValue)
                    } catch {
                        //
                    }
                }
#endif
            }
        }
    }

}
