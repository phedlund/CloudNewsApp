//
//  ArticleDetailView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/5/22.
//

import Foundation
import SwiftUI

struct ArticleDetailView: View {
    var item: CDItem

    @State private var feedTitle = ""
    @State private var dateText = ""
    @State private var itemTitle = ""
    @State private var itemURL = ""
    @State private var itemAuthor = ""
    @State private var summary = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 15)
                HStack {
                    Text(feedTitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(dateText)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Divider()
                if let url = URL(string: itemURL) {
                    Link(destination: url) {
                        Text(itemTitle)
                            .font(.title)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text(itemTitle)
                        .font(.title)
                        .multilineTextAlignment(.leading)
                }
                Text(itemAuthor)
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.gray)
                Text(Self.itemBody(item: item))
//                    .font(.body)
                    .lineSpacing(8.0)
                Divider()
                if let url = URL(string: itemURL) {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.headline)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
            let feed = CDFeed.feed(id: item.feedId)
            feedTitle = feed?.title ?? "Untitled"
            dateText = Self.dateText(item: item)
            itemTitle = Self.itemTitle(item: item)
            itemURL = Self.itemUrl(item: item)
            itemAuthor = Self.itemAuthor(item: item)
            summary = item.body ?? ""
        }
    }

    private static func dateText(item: CDItem) -> String {
        let dateNumber = TimeInterval(item.pubDate)
        let date = Date(timeIntervalSince1970: dateNumber)
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .medium;
        dateFormat.timeStyle = .short;
        return dateFormat.string(from: date)
    }

    private static func itemBody(item: CDItem) -> AttributedString {
        var bodyText = item.body
        bodyText = bodyText?.replacingOccurrences(of: "<br />", with: "\n")
        bodyText = bodyText?.replacingOccurrences(of: "<h2>", with: "## ")
        bodyText = bodyText?.replacingOccurrences(of: "</h2>", with: "\n")
        bodyText = bodyText?.replacingOccurrences(of: "<h3>", with: "### ")
        bodyText = bodyText?.replacingOccurrences(of: "</h3>", with: "\n")
        bodyText = bodyText?.replacingOccurrences(of: "<em>", with: "_")
        bodyText = bodyText?.replacingOccurrences(of: "</em>", with: "_")
        bodyText = bodyText?.replacingOccurrences(of: "<b>", with: "**")
        bodyText = bodyText?.replacingOccurrences(of: "</b>", with: "**")

        do {
            return try AttributedString(styledMarkdown: bodyText ?? "")
//            return try AttributedString(markdown: bodyText ?? "", options: .init(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible, languageCode: "en"), baseURL: nil)
        } catch {
            return ""
        }
    }

    private static func itemTitle(item: CDItem) -> String {
        return item.title ?? "Untitled"
    }

    private static func itemAuthor(item: CDItem) -> String {
        var author = ""
        if let itemAuthor = item.author, !itemAuthor.isEmpty {
            author = "By \(itemAuthor)"
        }
        return author
    }

    private static func itemUrl(item: CDItem) -> String {
        return item.url ?? ""
    }

}

//struct ArticleDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticleDetailView()
//    }
//}
