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

//    @State private var isDisabled = true
//
//    @Query private var items: [Item]

    var body: some View {
        Button {
            feedModel.markCurrentNodeRead()
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(feedModel.unreadCount == 0)
    }

}

//#Preview {
//    MarkReadButton()
//}
