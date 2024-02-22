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

    @Query private var items: [Item]

    private let errorCount = 0
    private var feed: Feed?

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
            feed = Feed.feed(id: id)
        case .folder(let id):
            if let feedIds = Feed.idsInFolder(folder: id) {
                predicate = #Predicate<Item> { feedIds.contains($0.feedId) && $0.unread == true }
            }
        }
        _items = Query(filter: predicate)
    }

    @ViewBuilder
    var body: some View {
        HStack {
            if feed?.updateErrorCount ?? 0 > 20 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            } else {
                let text = items.count > 0 ? "\(items.count)" : ""
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                        .fill(.gray)
                        .opacity(text.isEmpty ? 0.0 : 1.0))
            }
        }
        .onChange(of: items.count, initial: true) { _, newValue in
            if node.nodeType == .all {
                DispatchQueue.main.async {
#if os(macOS)
                    NSApp.dockTile.badgeLabel = newValue > 0 ? "\(newValue)" : ""
#else
                    UNUserNotificationCenter.current().setBadgeCount(newValue)
#endif
                }
            }
        }
    }

}
