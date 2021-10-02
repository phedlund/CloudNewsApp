//
//  ArticleImage.swift
//  iOCNews
//
//  Created by Peter Hedlund on 1/8/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation
import Kingfisher
import SwiftSoup

class ItemImageFetcher {

    private let validSchemas = ["http", "https", "file"]
    private let imagesToSkip = ["sdbnblognews", "feedads", "twitter_icon", "facebook_icon", "feedburner", "gplus-16", "_64", "blank", "pixel", "__ptq"]

    private var items: [CDItem]
    private var imageUrls = [URL]()

    init(_ items: [CDItem]) {
        self.items = items
    }

    func itemImages() {

        func stepTwo(_ item: CDItem) {
            if let urlString = item.url, let url = URL(string: urlString) {
                do {
                    let html = try String(contentsOf: url)
                    let doc: Document = try SwiftSoup.parse(html)
                    let meta: Element? = try doc.head()?.select("meta[property=og:image]").first()
                    if let ogImage = try meta?.attr("content"), let ogUrl = URL(string: ogImage) {
                        let isNotSkipped = imagesToSkip.allSatisfy({
                            !ogImage.contains($0)
                        })
                        if isNotSkipped {
                            item.imageLink = ogImage
                            imageUrls.append(ogUrl)
                        }
                    } else {
                        let twMeta: Element? = try doc.head()?.select("meta[property=twitter:image]").first()
                        if let twImage = try twMeta?.attr("content"), let twUrl = URL(string: twImage) {
                            let isNotSkipped = imagesToSkip.allSatisfy({
                                !twImage.contains($0)
                            })
                            if isNotSkipped {
                                item.imageLink = twImage
                                imageUrls.append(twUrl)
                            }                        }
                    }
                } catch {
                    print("error")
                }
            }
        }

        for item in items {
            if let summary = item.body {
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
                    if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                        item.imageLink = urlString
                        imageUrls.append(imgUrl)
                    } else {
                        stepTwo(item)
                    }
                } catch Exception.Error(_, let message) {
                    print(message)
                } catch {
                    print("error")
                }
            } else {
                stepTwo(item)
            }
        }
        if !imageUrls.isEmpty {
            let preFetcher = ImagePrefetcher(urls: imageUrls, options: []) { skippedResources, failedResources, completedResources in
                print("Skipped \(skippedResources.count)")
                print("Failed \(failedResources.count)")
                print("Completed \(completedResources.count)")
                for resource in completedResources {
                    print(resource.cacheKey)
                    print(resource.downloadURL.absoluteString)
                }
                try? NewsData.mainThreadContext.save()
            }
            preFetcher.start()
        }
    }

}
