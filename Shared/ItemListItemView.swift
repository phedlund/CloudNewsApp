//
//  ArticleListItemView.swift
//  iOCNews
//
//  Created by Peter Hedlund on 5/1/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftSoup
import SwiftUI
import Kingfisher

struct ItemListItemViev: View {
//    @Environment(\.verticalSizeClass) var verticalSizeClass
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @EnvironmentObject private var settings: Preferences
    @ObservedObject var item: CDItem
    @State private var cellHeight: CGFloat = 160.0
    @State private var thumbnailWidth: CGFloat = 145.0

    @ViewBuilder
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color(.white))
                .edgesIgnoringSafeArea(.all)
                .cornerRadius(4)
            VStack {
                HStack(alignment: .top, spacing: 10, content: {
                    ItemImageView(item: item, size: CGSize(width: thumbnailWidth, height: cellHeight))
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            TitleView(item: item)
                            FavIconDateAuthorView(item: item)
                            if settings.compactView /*|| horizontalSizeClass == .compact*/ {
                                EmptyView()
                            } else {
                                BodyView(item: item)
                            }
                            Spacer()
                        }
                        .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 0))
                    ItemStarredView(item: item)
                })
                //                        if /*horizontalSizeClass == .compact &&*/ !isCompactView  {
                //                            Text(transformedBody(provider.body))
                //                                .font(.subheadline)
                //                                .foregroundColor(Color(.black))
                //                                .padding(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 26))
                //                        } else {
                //                            EmptyView()
                //                        }
            }
        }
        .contextMenu {
            let isUnRead = item.unread
            let isStarred = item.starred
            Button {
                Task {
                    try? await NewsManager.shared.markRead(items: [item], unread: !isUnRead)
                }
            } label: {
                Label {
                    Text(isUnRead ? "Read" : "Unread")
                } icon: {
                    Image(systemName: isUnRead ? "eye" : "eye.slash")
                }
            }
            Button {
                Task {
                    try? await NewsManager.shared.markStarred(item: item, starred: !isStarred)
                }
            } label: {
                Label {
                    Text(isStarred ? "Unstar" : "Star")
                } icon: {
                    Image(systemName: isStarred ? "star" : "star.fill")
                }
            }
        }
        .padding([.trailing], 10)
        .background(Color(.white) // any non-transparent background
                        .cornerRadius(4)
                        .shadow(color: Color(white: 0.4, opacity: 0.35), radius: 2, x: 0, y: 2))
        .onReceive(settings.$compactView) { newCompactView in
            cellHeight = newCompactView ? 85.0 : 160.0
            thumbnailWidth = newCompactView ? 66.0 : 145.0
        }

        //            }
    }
    //        else {
    //            EmptyView()
    //        }
    //    }

}
