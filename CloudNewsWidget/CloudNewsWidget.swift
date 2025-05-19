//
//  CloudNewsWidget.swift
//  CloudNewsWidget
//
//  Created by Peter Hedlund on 5/4/25.
//

import SwiftData
import SwiftUI
import WidgetKit

enum DeepLink {

    case all
    case item(item: Item)

    var url: URL {
        var components = URLComponents()
        components.scheme = "cloudnews"

        switch self {
        case .all:
            components.path = "/widget/all"
        case .item(item: let item):
            components.path = "/widget/"
            components.queryItems = [URLQueryItem(name: "id", value: String(item.id)), URLQueryItem(name: "feedId", value: String(item.feedId))]
        }
        return components.url ?? URL(string: "cloudnews://")!
    }
}

struct Provider: TimelineProvider {

    private let placeholderData = [
        SnapshotData(title: "Article 1", feed: "Breaking News", pubDate: .now),
        SnapshotData(title: "Article 2", feed: "Breaking News", pubDate: .now),
        SnapshotData(title: "Article 3", feed: "Breaking News", pubDate: .now),
        SnapshotData(title: "Article 4", feed: "Breaking News", pubDate: .now),
        SnapshotData(title: "Article 5", feed: "Breaking News", pubDate: .now)]

    func placeholder(in context: Context) -> ArticleEntry {
        return ArticleEntry(date: Date(), snapshot: placeholderData)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArticleEntry) -> ()) {
        let entry = ArticleEntry(date: Date(), snapshot: placeholderData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        let entries = [ArticleEntry(date: now, snapshot: placeholderData)]

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

    static var fetchDescriptor: FetchDescriptor<Item> {
        var descriptor = FetchDescriptor<Item>(
            predicate: #Predicate { $0.unread == true },
            sortBy: [
                .init(\.id, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 10
        return descriptor
    }

    @Query(CloudNewsWidgetEntryView.fetchDescriptor) private var items: [Item]

    var body: some View {
        if items.count == 0 {
            ContentUnavailableView {
                Label("CloudNews", image: .widgetIcon)
            } description: {
                Text("No unread articles")
            }
        } else {
            let maxCount = family == .systemLarge ? 7 : 3
            let articles = items.prefix(maxCount)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center) {
                    Text("Recent Articles")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(Color(red: 0.8511758447, green: 0.3667599559, blue: 0.1705040038, opacity: 1.0))
                    Spacer()
                    Image(.widgetIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                    Link(destination: DeepLink.item(item: article).url) {
                        ItemViewWidget(article: article)
                    }
                    if index < articles.count - 1 {
                        Divider()
                    }
                }
                Spacer()
            }
            .padding(10)
            .widgetURL(DeepLink.all.url)
        }
    }

}

struct CloudNewsWidget: Widget {
    let kind: String = "CloudNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CloudNewsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .modelContainer(SharedDatabase.shared.modelContainer)
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
