//
//  FavIconRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/30/22.
//

import Combine
import UIKit
import Kingfisher

enum FetchError: Error {
    case noImage
}

class FavIcon: ObservableObject {
    #if os(macOS)
    @Published var image: NSImage

    init(image: NSImage) {
        self.image = image
    }

    #else
    @Published var image: UIImage

    init(image: UIImage) {
        self.image = image
    }
    #endif
}

@MainActor
class FavIconRepository: NSObject, ObservableObject {
    var icons = CurrentValueSubject<[String: FavIcon], Never>([:])

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
        icons.value["all"] = FavIcon(image: KFCrossPlatformImage(named: "rss")!)
        icons.value["starred"] = FavIcon(image: KFCrossPlatformImage(symbolName: "star.fill")!)
        update()
    }

    private func update() {
        if let folders = CDFolder.all() {
            for folder in folders {
                Task {
                    self.icons.value["folder_\(folder.id)"] = FavIcon(image: KFCrossPlatformImage(symbolName: "folder")!)
                }
            }
        }
        if let feeds = CDFeed.all() {
            for feed in feeds {
                ImageCache.default.retrieveImage(forKey: "feed_\(feed.id)") { result in
                    switch result {
                    case .success(let value):
                        self.icons.value["feed_\(feed.id)"] = FavIcon(image: value.image ??  KFCrossPlatformImage(named: "rss")!)
                    case .failure( _):
                        self.icons.value["feed_\(feed.id)"] = FavIcon(image: KFCrossPlatformImage(named: "rss")!)
                    }
                }
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
                ImageDownloader.default.downloadImage(with: url, options: []) { result in
                    switch result {
                    case .success(let value):
                        ImageCache.default.store(value.image, forKey: "feed_\(feed.id)")
                        self.icons.value["feed_\(feed.id)"] = FavIcon(image: value.image)
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
