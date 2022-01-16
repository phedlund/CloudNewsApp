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
import SwiftUI

actor ItemImageFetcher {
    private let validSchemas = ["http", "https", "file"]

    func itemImages() async throws {

        func stepTwo(_ item: CDItem) -> URL? {
            if let urlString = item.url, let url = URL(string: urlString) {
                do {
                    let html = try String(contentsOf: url)
                    let doc: Document = try SwiftSoup.parse(html)
                    let meta: Element? = try doc.head()?.select("meta[property=og:image]").first()
                    if let ogImage = try meta?.attr("content"), let ogUrl = URL(string: ogImage) {
                        return ogUrl
                    } else {
                        let twMeta: Element? = try doc.head()?.select("meta[property=twitter:image]").first()
                        if let twImage = try twMeta?.attr("content"), let twUrl = URL(string: twImage) {
                            return twUrl
                        }
                    }
                } catch {
                    print("error")
                }
            }
            return nil
        }

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
                        let filteredImages = images.filter { src in
                            if !validSchemas.contains(String(src.prefix(4))) {
                                return false
                            }
                            return true
                        }
                        if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                            itemImageUrl = imgUrl
                        } else {
                            itemImageUrl = stepTwo(item)
                        }
                    } catch Exception.Error(_, let message) {
                        print(message)
                    } catch {
                        print("error")
                    }
                } else {
                    itemImageUrl = stepTwo(item)
                }

                if let imageUrl = itemImageUrl {
                    await retrieve(imageUrl, item: item)
                } else {
                    try await CDItem.addImageLink(item: item, imageLink: "/dev/null")
                }
            }
        }
    }
    
}

extension ItemImageFetcher {

    func retrieve(_ url: URL, item: CDItem) async {
        let retrieveTask = Task { () -> KFCrossPlatformImage in
            let manager = KingfisherManager.shared
            let resource = ImageResource(downloadURL: url)
            print(resource.downloadURL.absoluteString)
            let sizeProcessor = SizeProcessor()
            let image = try await manager.retrieveImage(with: resource, options: [.processor(sizeProcessor)], progressBlock: nil, downloadTaskUpdated: nil)
            print("Image with key \(image.source.cacheKey)")
            return image.image
        }

        let result = await retrieveTask.result
        switch result {
        case .success( _):
            do {
                try await CDItem.addImageLink(item: item, imageLink: url.absoluteString)
            } catch { }
        case .failure( _):
            do {
                try await CDItem.addImageLink(item: item, imageLink: "/dev/null")
            } catch { }
        }
    }

}

extension KingfisherManager {

    func retrieveImage(with: ImageResource, options: KingfisherOptionsInfo?, progressBlock: DownloadProgressBlock?, downloadTaskUpdated: DownloadTaskUpdatedBlock?) async throws -> RetrieveImageResult {
        try await withCheckedThrowingContinuation { continuation in
            let _ = retrieveImage(with: with, options: options, progressBlock: progressBlock, downloadTaskUpdated: downloadTaskUpdated) { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct SizeProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "dev.pbh.sizeprocessor"

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case .image(let image):
            let size = image.size
            if size.height > 100, size.width > 100 {
                return image
            }
            print("Small image: \(size)")
            return nil
        case .data(let data):
            if let image = KFCrossPlatformImage(data: data) {
                let size = image.size
                if size.height > 100, size.width > 100 {
                    return image
                }
                print("Small image: \(size)")
                return nil
            }
            return nil
        }
    }
}
