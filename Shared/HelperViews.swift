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
            let unreadItems = node.items.filter( { $0.item?.unread ?? false })
            Task {
                let myItems = unreadItems.map( { $0.item! })
                try? await NewsManager.shared.markRead(items: myItems, unread: false)
            }
        } label: {
            Label {
                Text("Mark Read")
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .keyboardShortcut("a", modifiers: [])
        .disabled(node.unreadCount == 0)
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

