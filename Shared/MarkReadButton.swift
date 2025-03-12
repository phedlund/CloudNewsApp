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

    @Query private var items: [Item]

    init(fetchDescriptor: FetchDescriptor<Item>) {
        _items = Query(fetchDescriptor)
    }

    var body: some View {
        Button {
            newsModel.markItemsRead(items: items)
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
