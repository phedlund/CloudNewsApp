//
//  BadgeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/17/21.
//

import SwiftData
import SwiftUI

struct BadgeView: View {
    @Environment(NewsModel.self) private var newsModel
    let node: Node

    private var count: Int {
        newsModel.unreadCounts[node.id] ?? 0
    }

    var body: some View {
        HStack {
            if node.errorCount > 0 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            }
            if count > 0 {
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule().fill(.gray))
            }
        }
        .task(id: node.id) {
            await newsModel.refreshUnreadCount(for: node)
        }
        .onReceive(NotificationCenter.default.publisher(for: .unreadStateDidChange)) { _ in
            Task {
                await newsModel.refreshUnreadCount(for: node)
            }
        }
    }
}
