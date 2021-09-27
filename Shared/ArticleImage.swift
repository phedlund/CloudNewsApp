//
//  ArticleImage.swift
//  iOCNews
//
//  Created by Peter Hedlund on 1/8/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation
import Combine
import URLImage
import URLImageStore
import SwiftSoup
import UIKit

struct ArticleImage {

    static let validSchemas = ["http", "https", "file"]
    static let imagesToSkip = ["feedads","twitter_icon","facebook_icon","feedburner","gplus-16"]

    static func imageURL(urlString: String?, summary: String?) -> String? {
        if let urlString = urlString, let url = URL(string: urlString) {
            do {
                let html = try String(contentsOf: url)
                let doc: Document = try SwiftSoup.parse(html)
                let meta: Element? = try doc.head()?.select("meta[property=og:image]").first()
                if let ogImage = try meta?.attr("content") {
                    return ogImage
                }
                let twMeta: Element? = try doc.head()?.select("meta[property=twitter:image]").first()
                if let twImage = try twMeta?.attr("content") {
                    return twImage
                }
            } catch {
                print("error")
            }
        }

        if let summary = summary {
            do {
                let doc: Document = try SwiftSoup.parse(summary)
                let srcs: Elements = try doc.select("img[src]")
                let images = try srcs.array().map({ try $0.attr("src") })
                let filteredImages = images.filter { src in
                    if !validSchemas.contains(String(src.prefix(4))) {
                        return false
                    }
                    for skip in imagesToSkip {
                        if src.contains(skip) {
                            return false
                        }
                    }
                    return true
                }
                return filteredImages.first
            } catch Exception.Error(_, let message) {
                print(message)
            } catch {
                print("error")
            }
        }
        return nil
    }

}

final class ThumbnailModel: ObservableObject {

    static let downloadService = URLImageService(fileStore: URLImageFileStore(), inMemoryStore: URLImageInMemoryStore())
    let url: URL

    private var cancellable: AnyCancellable?

    init(url: URL) {
        self.url = url
    }

    @Published private(set) var image: CGImage?

    var isLoaded: Bool {
        image != nil
    }

    func load() {
        guard image == nil && cancellable == nil else {
            return
        }

        cancellable = ThumbnailModel.downloadService
            .remoteImagePublisher(url, identifier: nil)
            .sink { [weak self] result in
                guard let self = self else {
                    return
                }

                self.cancellable = nil
            }
            receiveValue: { info in
                print("Downloaded image with size \(info.size)")
                self.image = info.cgImage
            }
    }

}
