//
//  ItemStarredVIew.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/27/21.
//

import SwiftUI

struct ItemStarredView: View {

    var item: CDItem

    @ViewBuilder
    var body: some View {
        VStack {
            if item.starred {
                Image(systemName: "star.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 16, height: 16, alignment: .center)
            } else {
                HStack {
                    Spacer()
                }
                .frame(width: 16)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
    }
}
