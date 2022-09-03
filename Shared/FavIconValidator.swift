//
//  FavIconFetcher.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import Foundation
import Kingfisher

enum FetchError: Error {
    case noImage
}

class FavIconHelper {

    static func icon(for feed: CDFeed) async -> SystemImage {
        if let link = feed.faviconLinkResolved, !link.isEmpty, let url = URL(string: link) {
            return await withCheckedContinuation({
                (continuation: CheckedContinuation<SystemImage, Never>) in
                KingfisherManager.shared.retrieveImage(with: url) { result in
                    switch result {
                    case .success(let value):
                        continuation.resume(returning: value.image)
                    case .failure( _):
                        continuation.resume(returning: SystemImage(named: "rss")!)
                    }
                }
            })
        } else {
            return SystemImage(named: "rss")!
        }
    }

}

actor FavIconValidator {

    private let validSchemas = ["http", "https", "file"]

    func fetch() async throws {
        if let feeds = CDFeed.all() {
            for feed in feeds {
                if let link = feed.faviconLink,
//                   link != "data:null",
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

    func validateImageUrl(from url: URL, feed: CDFeed) async throws {
        let request = URLRequest.init(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                try await CDFeed.addFavIconLinkResolved(feed: feed, link: url.absoluteString)
            default:
                throw FetchError.noImage
            }
        }
    }

}
