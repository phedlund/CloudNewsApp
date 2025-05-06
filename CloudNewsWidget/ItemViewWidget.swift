//
//  ItemViewWidget.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/5/25.
//

import Kingfisher
import SwiftUI

struct ItemViewWidget: View {

    let article: SnapshotData

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if article.thumbnailUrl != nil {
                KFImage(article.thumbnailUrl)
                    .placeholder {
                        Image(.rss)
                            .font(.system(size: 18, weight: .light))
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipped()
                Spacer(minLength: 6)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(article.title)
                    .font(.footnote)
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(.primary)
                HStack(spacing: 0) {
                    Text(article.feed)
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
