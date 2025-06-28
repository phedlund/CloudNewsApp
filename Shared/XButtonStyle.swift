//
//  XButtonStyle.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/22/22.
//

import SwiftUI

struct XButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "xmark")
            .font(.title2)
    }
}
