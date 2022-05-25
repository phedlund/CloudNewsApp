//
//  FavIconFetcher.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/24/21.
//

import Foundation

enum FetchError: Error {
    case noImage
}

actor FavIconFetcher {

    private let validSchemas = ["http", "https", "file"]

    func fetch() async throws {
        var result = SystemImage(named: "rss")?.asPngData() ?? SystemImage().asPngData()
        if let feeds = CDFeed.all() {
            for feed in feeds {
                if let link = feed.faviconLink,
                   link != "rss",
                   let url = URL(string: link),
                   let scheme = url.scheme,
                   validSchemas.contains(scheme) {
                    do {
                        result = try await downloadImage(from: url)
                        try await CDFeed.addFavIcon(feed: feed, iconData: result ?? Data())
                    } catch let error {
                        if error as? FetchError == FetchError.noImage {
                            if let feedUrl = URL(string: feed.link ?? ""),
                               let host = feedUrl.host,
                               let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                                do {
                                    result = try await downloadImage(from: url)
                                    try await CDFeed.addFavIcon(feed: feed, iconData: result ?? Data())
                                } catch { }
                            }
                        }
                    }
                } else {
                    if let feedUrl = URL(string: feed.link ?? ""),
                       let host = feedUrl.host,
                       let url = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico") {
                        do {
                            result = try await downloadImage(from: url)
                            try await CDFeed.addFavIcon(feed: feed, iconData: result ?? Data())
                        } catch { }
                    }
                }
            }
        }
    }

    func downloadImage(from url: URL) async throws -> Data {
        let request = URLRequest.init(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
            print(String(data: data, encoding: .utf8) ?? "")
            switch httpResponse.statusCode {
            case 200:
                return data
            default:
                throw FetchError.noImage
            }
        }
        return data
    }

}
