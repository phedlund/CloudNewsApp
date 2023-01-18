//
//  FavIconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/17/23.
//

import Kingfisher
import SwiftUI

struct FavIconView: View {
    @EnvironmentObject private var favIconRepository: FavIconRepository
    var cacheKey: String

    @State private var icon = KFCrossPlatformImage(named: "rss")!

    @ViewBuilder
    var body: some View {
        Image(uiImage: favIconRepository.icons.value[cacheKey]?.image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 22, height: 22)
            .onReceive(favIconRepository.icons) { newValue in
                icon = newValue[cacheKey]?.image ?? KFCrossPlatformImage(named: "rss")!
            }
    }
}
