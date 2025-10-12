//
//  MarkReadButton.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/19/23.
//

import SwiftData
import SwiftUI

struct MarkReadButton: View {
    @Environment(NewsModel.self) private var newsModel
    @Environment(\.modelContext) private var modelContext
    @Query private var nodes: [Node]

    var nodeType: NodeType?

    private var effectiveNodeType: NodeType {
        nodeType ?? newsModel.currentNodeType
    }

    private var node: Node? {
        nodes.first { $0.type == effectiveNodeType }
    }

    private var unreadCount: Int {
        guard let node else { return 0 }
        return newsModel.unreadCounts[node.id] ?? 0
    }

    var body: some View {
        Button(role: .confirm) {
            Task {
                if let nodeType {
                    newsModel.currentNodeType = nodeType
                }
                await newsModel.updateUnreadItemIds()
                await newsModel.markCurrentItemsRead()

                if let node {
                    await newsModel.refreshUnreadCount(for: node)
                }
            }
        } label: {
            Label("Mark Read", systemImage: "checkmark")
        }
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(unreadCount == 0)
        .task(id: String(describing: effectiveNodeType)) {
            if let node {
                await newsModel.refreshUnreadCount(for: node)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .unreadStateDidChange)) { _ in
            Task {
                if let node {
                    await newsModel.refreshUnreadCount(for: node)
                }
            }
        }
    }
}

//#Preview {
//    MarkReadButton()
//}
