//
//  ItemViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/10/21.
//

import SwiftUI

extension View {
    @ViewBuilder
    func labelStyle(includeFavIcon: Bool) -> some View {
        if includeFavIcon {
            self.labelStyle(.titleAndIcon)
        } else {
            self.labelStyle(.titleOnly)
        }
    }
}

extension Image {

    func imageStyle(size: CGSize) -> some View {
        self
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
    }

}
