//
//  ItemImageManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/18/23.
//

import Combine
import UIKit
import Kingfisher
import SwiftSoup

class ItemImageManager: NSObject, ObservableObject {
    @Published var image: KFCrossPlatformImage?

    var item: CDItem

    private let validSchemas = ["http", "https", "file"]

    init(item: CDItem) {
        self.item = item
        super .init()
        load()
    }

    private func load() {
        ImageCache.default.retrieveImage(forKey: "item_\(item.id)") { result in
            switch result {
            case .success(let value):
                switch value {
                case .none:
                    Task {
                        try? await self.downloadImage()
                    }
                default:
                    self.image = value.image ?? KFCrossPlatformImage()
                }
            case .failure( _):
                Task {
                    try? await self.downloadImage()
                }
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
                    ImageCache.default.store(value.image, forKey: "item_\(self.item.id)")
                    self.image = value.image
                case .failure(let error):
                    print(error)
                }
            }
        }
    }

    private func stepTwo(_ item: CDItem) async -> URL? {
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
