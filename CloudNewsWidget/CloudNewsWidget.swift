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
        let now = Date()

        do {
            let snapshotData = try Snapshot.readSnapshot()
            entries.append(ArticleEntry(date: now, snapshot: snapshotData))
        } catch { }
//        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
//        let currentDate = Date()
//        for hourOffset in 0 ..< 5 {
//            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
//            let entry = ArticleEntry(date: entryDate, emoji: "😀")
//            entries.append(entry)
//        }

        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)

        let timeline = Timeline(entries: entries, policy: .after(nextUpdateDate ?? Date()))
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
        let articles = entry.snapshot.prefix(maxCount)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center) {
                Text("Recent Articles")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Color(red: 0.8511758447, green: 0.3667599559, blue: 0.1705040038, opacity: 1.0))
                Spacer()
                Image("widget.icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
            }
            ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                ItemViewWidget(article: article)
                if index < articles.count - 1 {
                    Divider()
                }
            }
            Spacer()
        }
        .padding(10)
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
