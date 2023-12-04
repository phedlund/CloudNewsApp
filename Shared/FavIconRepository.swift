//
//  FavIconRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/30/22.
//

import Kingfisher
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
#if os(macOS)
    var image: NSImage
#else
    var image: UIImage
#endif
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
//        update()
    }

    func update() {
        Task {
            do {
                try await self.fetch()
                print("Done fetching icons")
            } catch { }
            if let feeds = Feed.all() {
                for feed in feeds {
                    ImageCache.default.retrieveImage(forKey: "feed_\(feed.id)") { result in
                        switch result {
                        case .success(let value):
                            self.icons["feed_\(feed.id)"] = FavIcon(image: value.image ??  self.defaultIcon.image)
                        case .failure( _):
                            self.icons["feed_\(feed.id)"] = self.defaultIcon
                        }
                    }
                }
                print("Done loading icons")
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
                        try await validateImageUrl(from: url, feed: feed)
                    } catch let error {
                        if error as? FetchError == FetchError.noImage {
                            if let feedUrl = URL(string: feed.link ?? "data:null"),
                               let host = feedUrl.host,
                               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                                do {
                                    try await validateImageUrl(from: url, feed: feed)
                                } catch { }
                            }
                        }
                    }
                } else {
                    if let feedUrl = URL(string: feed.link ?? "data:null"),
                       let host = feedUrl.host,
                       let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                        do {
                            try await validateImageUrl(from: url, feed: feed)
                        } catch { }
                    }
                }
            }
        }
    }

    private func validateImageUrl(from url: URL, feed: Feed) async throws {
        let request = URLRequest.init(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                ImageDownloader.default.downloadImage(with: url, options: []) { result in
                    switch result {
                    case .success(let value):
                        ImageCache.default.store(value.image, forKey: "feed_\(feed.id)")
                        self.icons["feed_\(feed.id)"] = FavIcon(image: value.image)
                        print(value.image)
                    case .failure(let error):
                        print(error)
                    }
                }
            default:
                throw FetchError.noImage
            }
        }
    }

}
