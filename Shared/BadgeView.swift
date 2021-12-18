//
//  BadgeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/17/21.
//

import SwiftUI

struct BadgeView: View {
    @ObservedObject var node: Node

    @State private var unreadCount = 0
    @State private var errorCount = 0

    @ViewBuilder
    var body: some View {
        HStack {
            if node.errorCount > 20 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            } else {
                let text = node.unreadCount > 0 ? "\(node.unreadCount)" : ""
                Text(text)
                    .font(.subheadline)
                    .colorInvert()
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                                    .fill(.gray)
                                    .opacity(text.isEmpty ? 0.0 : 1.0))
            }
        }
        .onReceive(node.$unreadCount) {
            unreadCount = $0
        }
        .onReceive(node.$errorCount) {
            errorCount = $0
        }
    }

}
