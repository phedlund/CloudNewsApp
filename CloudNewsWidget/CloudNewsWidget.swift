//
//  CloudNewsWidget.swift
//  CloudNewsWidget
//
//  Created by Peter Hedlund on 5/4/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ArticleEntry {
        let placeholderData = [
            SnapshotData(title: "Article 1", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 2", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 3", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 4", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 5", feed: "Breaking News", pubDate: .now)]
        return ArticleEntry(date: Date(), snapshot: placeholderData)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArticleEntry) -> ()) {
        let placeholderData = [
            SnapshotData(title: "Article 1", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 2", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 3", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 4", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 5", feed: "Breaking News", pubDate: .now)]
        let entry = ArticleEntry(date: Date(), snapshot: placeholderData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [ArticleEntry] = []

        do {
            let snapshotData = try Snapshot.readSnapshot()
            entries.append(ArticleEntry(date: Date(), snapshot: snapshotData))
        } catch { }
//        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
//        let currentDate = Date()
//        for hourOffset in 0 ..< 5 {
//            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
//            let entry = ArticleEntry(date: entryDate, emoji: "😀")
//            entries.append(entry)
//        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

//    func relevances() async -> WidgetRelevances<Void> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct ArticleEntry: TimelineEntry {
    let date: Date
    let snapshot: [SnapshotData]
}

struct CloudNewsWidgetEntryView : View {
    @Environment(\.widgetFamily) var family: WidgetFamily
    @Environment(\.dynamicTypeSize) var dynamicTypeSize: DynamicTypeSize

    var entry: Provider.Entry

    var body: some View {
        let maxCount = family == .systemLarge ? 7 : 3
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.snapshot.prefix(maxCount), id: \.self) { article in
                VStack(alignment: .leading, spacing: 3) {
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
                    Divider()
                }
            }
        }
        .padding(10)
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return formatter.string(from: date)
    }

}

struct CloudNewsWidget: Widget {
    let kind: String = "CloudNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CloudNewsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Articles")
        .description("A list of the most recent articles from your feeds.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    CloudNewsWidget()
} timeline: {
    ArticleEntry(date: .now, snapshot: [
        SnapshotData(title: "Article 1", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 2", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 3", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 4", feed: "Breaking News", pubDate: .now), SnapshotData(title: "Article 5", feed: "Breaking News", pubDate: .now)])
}
