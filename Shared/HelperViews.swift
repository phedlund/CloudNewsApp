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
    @ObservedObject var node: Node

    var body: some View {
        Button {
            let unreadItems = CDItem.unreadItems(nodeType: node.nodeType)
            Task {
                try? await NewsManager.shared.markRead(items: unreadItems, unread: false)
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
    @ObservedObject var item: CDItem
    
    var body: some View {
        let subject = item.title ?? "Untitled"
        let message = item.displayBody
        if let url = item.webViewHelper.url {
            if url.scheme?.hasPrefix("file") ?? false {
                if let urlString = item.url, let itemUrl = URL(string: urlString) {
                    ShareLink(item: itemUrl, subject: Text(subject), message: Text(message))
                }
            } else {
                ShareLink(item: url, subject: Text(subject), message: Text(message))
            }
        } else if !subject.isEmpty {
            ShareLink(item: subject, subject: Text(subject), message: Text(message))
        }
    }
    
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct ClearSelectionStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(Color.clear)
    }
}

