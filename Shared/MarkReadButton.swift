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
    @Environment(\.modelContext) private var modelContext

    @Query private var items: [Item]
    @Query private var feeds: [Feed]
    @Query private var folders: [Folder]

    init(fetchDescriptor: FetchDescriptor<Item> = .init()) {
        _items = Query(fetchDescriptor)
    }

    var body: some View {
        Button {
            feedModel.markItemsRead(items: items)
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
