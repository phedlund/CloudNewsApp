//
//  ItemImageManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/18/23.
//

import Combine
import Kingfisher
import SwiftSoup

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class ItemImageManager: NSObject, ObservableObject {
    @Published var image: SystemImage?

    private let validSchemas = ["http", "https", "file"]
    private let item: Item
    private let key: String

    init(item: Item) {
        self.item = item
        key = "item_\(item.id)"
        super.init()
        load()
    }

    private func load() {
        if ImageCache.default.isCached(forKey: key) {
            ImageCache.default.retrieveImage(forKey: key) { result in
                switch result {
                case .success(let value):
                    self.image = value.image ?? SystemImage()
                case .failure( _):
                    break
                }
            }
        } else {
            Task {
                try? await self.downloadImage()
            }
        }
    }

    private func downloadImage() async throws {
        var itemImageUrl: URL?
        if let urlString = item.mediaThumbnail, let imgUrl = URL(string: urlString) {
            itemImageUrl = imgUrl
        } else if let summary = item.body {
            do {
                let doc: Document = try SwiftSoup.parse(summary)
                let srcs: Elements = try doc.select("img[src]")
                let images = try srcs.array().map({ try $0.attr("src") })
                let filteredImages = images.filter({ validSchemas.contains(String($0.prefix(4))) })
                if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                    itemImageUrl = imgUrl
                } else if let stepTwoUrl = await stepTwo(item) {
                    itemImageUrl = stepTwoUrl
                }
            } catch Exception.Error(_, let message) { // An exception from SwiftSoup
                print(message)
            } catch(let error) {
                print(error.localizedDescription)
            }
        } else {
            itemImageUrl = await stepTwo(item)
        }

        if let itemImageUrl {
            ImageDownloader.default.downloadImage(with: itemImageUrl, options: []) { result in
                switch result {
                case .success(let value):
                    ImageCache.default.store(value.image, forKey: self.key)
                    self.image = value.image
                case .failure(let error):
                    print(error)
                }
            }
        }
    }

    private func stepTwo(_ item: Item) async -> URL? {
        if let urlString = item.url, let url = URL(string: urlString) {
            do {
                let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                if let html = String(data: data, encoding: .utf8) {
                    let doc: Document = try SwiftSoup.parse(html)
                    if let meta = try doc.head()?.select("meta[property=og:image]").first() as? Element {
                        let ogImage = try meta.attr("content")
                        let ogUrl = URL(string: ogImage)
                        return ogUrl
                    } else if let meta = try doc.head()?.select("meta[property=twitter:image]").first() as? Element {
                        let twImage = try meta.attr("content")
                        let twUrl = URL(string: twImage)
                        return twUrl
                    } else {
                        return nil
                    }
                }
            } catch(let error) {
                print(error.localizedDescription)
            }
        }
        return nil
    }

}
