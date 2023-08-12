//
//  HelperViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/22.
//

import Combine
import Foundation
import SwiftUI

struct MarkReadButton: View {
    @State var node: Node

    var body: some View {
        Button {
            Task {
//                let unreadItems = Item.unreadItems(nodeType: node.nodeType)
//                try? await NewsManager.shared.markRead(items: unreadItems, unread: false)
            }
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [.control])
        .disabled(node.unreadCount == 0)
    }
}

struct ShareLinkButton: View {
    @State var item: Item
    
    var body: some View {
        let subject = item.title ?? "Untitled"
        let message = item.displayBody
//        if let url = item.webViewHelper.url {
//            if url.scheme?.hasPrefix("file") ?? false {
//                if let urlString = item.url, let itemUrl = URL(string: urlString) {
//                    ShareLink(item: itemUrl, subject: Text(subject), message: Text(message))
//                }
//            } else {
//                ShareLink(item: url, subject: Text(subject), message: Text(message))
//            }
//        } else if !subject.isEmpty {
//            ShareLink(item: subject, subject: Text(subject), message: Text(message))
//        }
        EmptyView()
    }
    
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
