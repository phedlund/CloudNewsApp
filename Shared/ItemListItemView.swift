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
    @AppStorage(StorageKeys.compactView) private var compactView: Bool?
    @ObservedObject var item: CDItem

    @ViewBuilder
    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        let isCompactView = compactView ?? false
        ZStack {
            Rectangle()
                .foregroundColor(Color(.white))
                .edgesIgnoringSafeArea(.all)
                .cornerRadius(4)
            VStack(content: {
                HStack(alignment: .top, spacing: 10, content: {
                    ItemImageView(item: item)
                    HStack {
                        VStack(alignment: .leading, spacing: 8, content: {
                            TitleView(item: item)
                            FavIconDateAuthorView(item: item)
                            if isCompactView /*|| horizontalSizeClass == .compact*/ {
                                EmptyView()
                            } else {
                                BodyView(item: item)
                            }
                            if isCompactView /*|| horizontalSizeClass == .compact*/ {
                                EmptyView()
                            } else {
                                Spacer()
                            }
                        })
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
            })
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
        //            }
    }
    //        else {
    //            EmptyView()
    //        }
    //    }
    
}
