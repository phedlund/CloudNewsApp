//
//  FavIconRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/30/22.
//

import Nuke
import Observation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum FetchError: Error {
    case noImage
}

struct FavIcon {
    var name = ""
    var image: SystemImage
}

@Observable
class FavIconRepository {
    var icons = [String: FavIcon]()

    let defaultIcon = FavIcon(name: "rss", image: SystemImage())

    private let validSchemas = ["http", "https", "file"]

    init() {
        icons["all"] = defaultIcon
        icons["starred"] = FavIcon(name: "star.fill", image: SystemImage())
        icons["folder"] = FavIcon(name: "folder", image: SystemImage())
    }

    func update() {
        Task {
            do {
                try await self.fetch()
            } catch {
                //
            }
        }
    }
    
    private func fetch() async throws {
        if let feeds = Feed.all() {
            for feed in feeds {
                if let link = feed.faviconLink,
                   let url = URL(string: link),
                   let scheme = url.scheme,
                   validSchemas.contains(scheme) {
                    do {
                        try await downloadFavIcon(from: url, feed: feed)
                    } catch let error {
                        if error as? FetchError == FetchError.noImage {
                            if let feedUrl = URL(string: feed.link ?? "data:null"),
                               let host = feedUrl.host,
                               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                                do {
                                    try await downloadFavIcon(from: url, feed: feed)
                                } catch { }
                            }
                        }
                    }
                } else {
                    if let feedUrl = URL(string: feed.link ?? "data:null"),
                       let host = feedUrl.host,
                       let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                        do {
                            try await downloadFavIcon(from: url, feed: feed)
                        } catch { }
                    }
                }
            }
        }
    }

    private func downloadFavIcon(from url: URL, feed: Feed) async throws {
        do {
            let image = try await ImagePipeline.shared.image(for: url)
            self.icons["feed_\(feed.id)"] = FavIcon(image: image)
        } catch {
            self.icons["feed_\(feed.id)"] = FavIcon(name: "rss", image: SystemImage())
        }
    }

}
