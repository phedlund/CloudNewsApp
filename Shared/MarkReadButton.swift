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

    var nodeType: NodeType?

    var body: some View {
        Button(role: .confirm) {
            Task {
                // Ensure the model targets the right node for the underlying operations
                if let nodeType {
                    newsModel.currentNodeType = nodeType
                }
                await newsModel.updateUnreadItemIds()
                for itemID in newsModel.unreadItemIds {
                    if let item = modelContext.model(for: itemID) as? Item {
                        item.unread = false
                    }
                }
                await newsModel.markCurrentItemsRead()
            }
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(isMarkReadDisabled)
    }

    private var isMarkReadDisabled: Bool {
        let key = nodeType ?? newsModel.currentNodeType
        return (newsModel.unreadCounts[key] ?? 0) == 0
    }
}

//#Preview {
//    MarkReadButton()
//}
