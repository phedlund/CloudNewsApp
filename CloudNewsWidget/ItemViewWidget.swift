//
//  ItemViewWidget.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/5/25.
//

import SwiftUI

struct ItemViewWidget: View {

    let article: Item

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if let thumbnail = article.thumbnail, let uiImage = SystemImage(data: thumbnail) {
                #if os(macOS)
                Image(nsImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipped()
                #else
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipped()
                #endif
                Spacer(minLength: 6)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(article.title ?? Constants.genericUntitled)
                    .font(.footnote)
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(.primary)
                HStack(spacing: 0) {
                    Text(article.feed?.title ?? Constants.untitledFeedName)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedDate(article.pubDate))
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }

}
