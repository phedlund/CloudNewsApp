//
//  FavIconView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/17/23.
//

import SwiftUI

struct FavIconView: View {
    var nodeType: NodeType
    
    @State private var url: URL?

    @ViewBuilder
    var body: some View {
        Group {
            switch nodeType {
            case .all, .empty:
                Image("rss")
                    .font(.system(size: 18, weight: .light))
            case .starred:
                Image(systemName: "star.fill")
            case .folder( _):
                Image(systemName: "folder")
            case .feed( _):
                AsyncImage(url: url)  { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        Image("rss")
                            .font(.system(size: 18, weight: .light))
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 22, height: 22)
            }
        }
        .task {
            Task {
                switch nodeType {
                case .feed(let id):
                    url = try await Feed.feed(id: id)?.favIconUrl
                default:
                    url = nil
                }
            }
        }
    }

}
