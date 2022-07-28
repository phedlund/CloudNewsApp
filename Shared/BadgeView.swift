//
//  BadgeView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/17/21.
//

import SwiftUI

struct BadgeView: View {
    var unreadCount: Int
    var errorCount: Int

    @ViewBuilder
    var body: some View {
        HStack {
            if errorCount > 20 {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            } else {
                let text = unreadCount > 0 ? "\(unreadCount)" : ""
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    .background(Capsule()
                                    .fill(.gray)
                                    .opacity(text.isEmpty ? 0.0 : 1.0))
            }
        }
    }

}
