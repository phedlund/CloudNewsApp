//
//  ErrorLabel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/22.
//

import SwiftUI

struct ErrorLabel: View {
    @Binding var message: String

    @ViewBuilder
    var body: some View {
        if message.isEmpty {
            EmptyView()
        } else {
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.black, .red)
            }
        }
    }
}

struct ErrorLabel_Previews: PreviewProvider {
    static var previews: some View {
        ErrorLabel(message: .constant(""))
    }
}
