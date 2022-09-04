//
//  FavIconRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/30/22.
//

import Combine
import Foundation
import Kingfisher

enum FetchError: Error {
    case noImage
}

@MainActor
class FavIconRepository: NSObject, ObservableObject {
    var icons = CurrentValueSubject<[NodeType: String], Never>([:])

    private let validSchemas = ["http", "https", "file"]
    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: nil).eraseToAnyPublisher()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        syncPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    do {
                        try await self?.fetch()
                    } catch { }
                }
                self?.update()
            }
            .store(in: &cancellables)
        icons.value[.all] = "rss"
        icons.value[.starred] = "star.fill"
        update()
    }

    private func update() {
        if let folders = CDFolder.all() {
            for folder in folders {
                Task {
                    self.icons.value[.folder(id: folder.id)] = "folder"
                }
            }
        }
        if let feeds = CDFeed.all() {
            for feed in feeds {
                icons.value[.feed(id: feed.id)] = feed.faviconLinkResolved
            }
        }
    }

    private func fetch() async throws {
        if let feeds = CDFeed.all() {
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

    private func validateImageUrl(from url: URL, feed: CDFeed) async throws {
        let request = URLRequest.init(url: url)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                icons.value[.feed(id: feed.id)] = url.absoluteString
                try await CDFeed.addFavIconLinkResolved(feed: feed, link: url.absoluteString)
            default:
                throw FetchError.noImage
            }
        }
    }

}
