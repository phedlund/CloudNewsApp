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
        Button {
            Task {
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
        .disabled(isDisabled)
        .onChange(of: newsModel.currentNodeType) { _, _ in
            Task {
                isDisabled = (try? await newsModel.unreadItemIds.count == 0) ?? true
            }
        }
    }

}

//#Preview {
//    MarkReadButton()
//}
