//
//  ArticleImage.swift
//  iOCNews
//
//  Created by Peter Hedlund on 1/8/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation
import Nuke
import SwiftSoup

class ItemImageFetcher {

    private struct ItemURLContainer {
        let item: CDItem
        let url: URL
    }

    private let validSchemas = ["http", "https", "file"]

//    func prefetchImages(_ urlStrings: [String?]) {
//        var imageRequests = [ImageRequest]()
//        for urlString in urlStrings {
//            if let urlString = urlString {
//                imageRequests.append(ImageRequest(url: URL(string: urlString), processors: [SizeProcessor()], priority: .veryHigh, options: [], userInfo: nil))
//            }
//        }
//        let prefetcher = ImagePrefetcher()
//        prefetcher.startPrefetching(with: imageRequests)
//    }

    func itemURL(_ item: CDItem) async throws {
            var itemImageUrl: String?
            if let imageLink = item.imageLink,
               !imageLink.isEmpty,
               imageLink != "data:null" {
                itemImageUrl = imageLink
            } else if let urlString = item.mediaThumbnail, let imgUrl = URL(string: urlString) {
                itemImageUrl = imgUrl.absoluteString
            } else if let summary = item.body {
                do {
                    let doc: Document = try SwiftSoup.parse(summary)
                    let srcs: Elements = try doc.select("img[src]")
                    let images = try srcs.array().map({ try $0.attr("src") })
                    let filteredImages = images.filter({ validSchemas.contains(String($0.prefix(4))) })
                    if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                        itemImageUrl = imgUrl.absoluteString
                    } else if let stepTwoUrl = stepTwo(item) {
                        itemImageUrl = stepTwoUrl.absoluteString
                    }
                } catch Exception.Error(_, let message) { // An exception from SwiftSoup
                    print(message)
                } catch(let error) {
                    print(error.localizedDescription)
                }
            } else {
                itemImageUrl = stepTwo(item)?.absoluteString
            }

            if let imageUrlString = itemImageUrl, let _ = URL(withCheck: imageUrlString) {
                try await CDItem.addImageLink(item: item, imageLink: imageUrlString)
            } else {
                try await CDItem.addImageLink(item: item, imageLink: "data:null")
            }
    }

    func itemURLs() async throws {
        if let items = CDItem.itemsWithoutImageLink() {
            for item in items {
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
                        } else if let stepTwoUrl = stepTwo(item) {
                            itemImageUrl = stepTwoUrl
                        }
                    } catch Exception.Error(_, let message) { // An exception from SwiftSoup
                        print(message)
                    } catch(let error) {
                        print(error.localizedDescription)
                    }
                } else {
                    itemImageUrl = stepTwo(item)
                }

                if let imageUrl = itemImageUrl {
                    try await CDItem.addImageLink(item: item, imageLink: imageUrl.absoluteString)
                } else {
                    try await CDItem.addImageLink(item: item, imageLink: "data:null")
                }
            }
        }
    }

    private func stepTwo(_ item: CDItem) -> URL? {
        if let urlString = item.url, let url = URL(string: urlString) {
            do {
                let html = try String(contentsOf: url)
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
            } catch(let error) {
                print(error.localizedDescription)
            }
        }
        return nil
    }

}

struct SizeProcessor: ImageProcessing {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "dev.pbh.sizeprocessor"
    let item: CDItem

    // Convert input data/image to target image and return it.
    func process(_ image: PlatformImage) -> PlatformImage? {
        let size = image.size
        if size.height > 100, size.width > 100 {
            return image
        }
        print("Small image: \(size)")
        Task(priority: .high) {
            try await CDItem.addImageLink(item: item, imageLink: "data:null")
        }
        return nil
    }
}
