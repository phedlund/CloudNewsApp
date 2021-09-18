//
//  ArticleListItemView.swift
//  iOCNews
//
//  Created by Peter Hedlund on 5/1/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftSoup
import SwiftUI
import URLImage

struct ItemListItemViev: View {
//    @Environment(\.verticalSizeClass) var verticalSizeClass
//    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @AppStorage(StorageKeys.compactView) private var compactView: Bool?
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?
    @AppStorage(StorageKeys.showFavIcons) private var showFavIcons: Bool?
    @ObservedObject var item: CDItem

    var body: some View {
        let textColor = item.unread ? Color.pbh.whiteText : Color.pbh.whiteReadText
        let isCompactView = /*compactView ??*/ false
        let isShowingThumbnails = /*showThumbnails ??*/ true
//        let cellHeight: CGFloat = isCompactView ? 84 : 150
        let provider = item
//            GeometryReader { geometry in
//                let cellWidth = min(geometry.size.width * 0.95, 690)
                ZStack {
                    Rectangle()
                        .foregroundColor(Color(.white))
                        .edgesIgnoringSafeArea(.all)
                        .cornerRadius(4)
                    VStack(content: {
                        HStack(alignment: .top, spacing: 10, content: {
                            if isShowingThumbnails && provider.thumbnailURL != nil {
                                VStack {
                                    URLImage(provider.thumbnailURL!) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .environment(\.urlImageOptions, URLImageOptions(
                                        maxPixelSize: CGSize(width: 600.0, height: 600.0)
                                    ))
                                    .frame(width: isCompactView ? 66 : 145, alignment: .center)
                                    .cornerRadius(0)
                                    .opacity(item.unread ? 1.0 : 0.4)
                                }
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            } else {
                                Spacer(minLength: 2)
                            }
                            HStack {
                                VStack(alignment: .leading, spacing: 8, content: {
                                    Text(transformedTitel(provider.title))
                                        .font(.headline)
                                        .foregroundColor(textColor)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true) //force wrapping
                                    HStack {
                                        if showFavIcons ?? true {
                                            item.favIcon
                                        } else {
                                            EmptyView()
                                        }
                                        Text(provider.dateAuthorFeed)
                                            .font(.subheadline)
                                            .foregroundColor(textColor)
                                            .italic()
                                            .lineLimit(1)
                                    }
                                    if isCompactView /*|| horizontalSizeClass == .compact*/ {
                                        EmptyView()
                                    } else {
                                        Text(transformedBody(provider.body))
                                            .lineLimit(4)
                                            .font(.subheadline)
                                            .foregroundColor(textColor)
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
                            VStack {
                                if provider.starred {
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
                .padding([.trailing], 10)
                .background(Color(.white) // any non-transparent background
                                .cornerRadius(4)
                                .shadow(color: Color(white: 0.5, opacity: 0.25), radius: 3, x: 0, y: 3))
//            }
    }
//        else {
//            EmptyView()
//        }
//    }


    private func transformedTitel(_ value: String?) -> String {
        guard let titleValue = value else {
            return "No Title"
        }

        return plainSummary(raw: titleValue as String)
    }

    private func transformedBody(_ value: String?) -> String {
        guard let summaryValue = value else {
            return "No Summary"
        }

        var summary: String = summaryValue as String
        if summary.range(of: "<style>", options: .caseInsensitive) != nil {
            if summary.range(of: "</style>", options: .caseInsensitive) != nil {
                if let start = summary.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                    let end = summary.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                    let sub = summary[start..<end]
                    summary = summary.replacingOccurrences(of: sub, with: "")
                }
            }
        }
        return  plainSummary(raw: summary)
    }

    private func plainSummary(raw: String) -> String {
        guard let doc: Document = try? SwiftSoup.parse(raw) else {
            return raw
        } // parse html
        guard let txt = try? doc.text() else {
            return raw
        }
        return txt
    }


}

//@available(iOS 13.0, *)
//struct ArticleListItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        let data = previewData()
//        Group {
//            List(/*@START_MENU_TOKEN@*/0 ..< 5/*@END_MENU_TOKEN@*/) { item in
//                ArticleListItemView(provider: data[item])
//            }
//            List(/*@START_MENU_TOKEN@*/0 ..< 5/*@END_MENU_TOKEN@*/) { item in
//                ArticleListItemView(provider: data[item])
//            }
//            .previewDevice("iPhone 12 Pro")
//        }
//    }
//}

//@available(iOS 13.0, *)
//struct Show: ViewModifier {
//    @Binding var isVisible: Bool
//
//    @ViewBuilder
//    func body(content: Content) -> some View {
//        if isVisible {
//            content
//        } else {
//            content.hidden()
//        }
//    }
//}
//
//@available(iOS 13.0, *)
//extension View {
//    func show(isVisible: Binding<Bool>) -> some View {
//        ModifiedContent(content: self, modifier: Show(isVisible: isVisible))
//    }
//}
