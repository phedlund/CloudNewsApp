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

    @State private var isDisabled = true

    var body: some View {
        Button(role: .confirm) {
            Task {
                await newsModel.updateUnreadItemIds()
                for itemID in newsModel.unreadItemIds {
                    if let item = modelContext.model(for: itemID) as? Item {
                        item.unread = false
                    }
                }
                await newsModel.markCurrentItemsRead()
            }
        }
        .id(newsModel.currentNodeType)
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(isDisabled)
        .onChange(of: newsModel.currentNodeType, initial: true) { _, newValue in
            isDisabled = newsModel.unreadCounts[newsModel.currentNodeType] == 0
        }
        .onChange(of: newsModel.unreadCounts, initial: true) { _, newValue in
            isDisabled = newValue[newsModel.currentNodeType] == 0
        }
    }

}

//#Preview {
//    MarkReadButton()
//}
