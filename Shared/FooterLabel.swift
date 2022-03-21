//
//  ErrorLabel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/22.
//

import SwiftUI

struct FooterLabel: View {
    @Binding var message: String
    @Binding var success: Bool

    @ViewBuilder
    var body: some View {
        if message.isEmpty {
            EmptyView()
        } else {
            Label {
                Text(message)
            } icon: {
                if success {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green, .green)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.black, .red)
                }
            }
        }
    }
}

struct ErrorLabel_Previews: PreviewProvider {
    static var previews: some View {
        FooterLabel(message: .constant(""), success: .constant(true))
    }
}
