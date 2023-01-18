//
//  FavIconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/17/23.
//

import Kingfisher
import SwiftUI

struct FavIconView: View {
    @ObservedObject var favIcon: FavIcon

    @ViewBuilder
    var body: some View {
        Image(uiImage: favIcon.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 22, height: 22)
    }
}
