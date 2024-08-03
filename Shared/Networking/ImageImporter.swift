//
//  ImageImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/3/24.
//

import Foundation
import OSLog
import SwiftData

class ImageImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ImageImporter.self))
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updateFaviconsInDatabase() async {
        do {
            if let feeds = modelContext.allFeeds() {
                for feed in feeds {
                    if let url = try await favIconUrl(feed) {
                        if let data = try? Data(contentsOf: url) {
                            let iconModel = ImageModel(id: feed.id, pngData: data)
                            feed.imageModel = iconModel
                        }
                    }
                }
            }
            try? modelContext.save()
        } catch {
            print("Error fetching data")
            print(error.localizedDescription)
        }
    }

    private func favIconUrl(_ feed: Feed) async throws -> URL? {
        let validSchemas = ["http", "https", "file"]
        var itemImageUrl: URL?
        if let link = feed.faviconLink,
           let url = URL(string: link),
           let scheme = url.scheme,
           validSchemas.contains(scheme) {
            itemImageUrl = url
        } else {
            if let feedUrl = URL(string: feed.link ?? "data:null"),
               let host = feedUrl.host,
               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                itemImageUrl = url
            }
        }
        return itemImageUrl
    }

}
