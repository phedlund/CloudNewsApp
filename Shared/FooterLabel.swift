//
//  ErrorLabel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/22.
//

import SwiftUI

struct FooterLabel: View {
    var message: String
    var success: Bool

    @ViewBuilder
    var body: some View {
        if message.isEmpty {
            EmptyView()
        } else {
            HStack {
                Label {
                    Text(message)
#if os(macOS)
                        .font(.footnote)
#endif
                } icon: {
                    if success {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green, .green)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.black, .red)
                    }
                }
                Spacer()
            }
        }
    }
}
