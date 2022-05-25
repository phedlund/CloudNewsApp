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

class ItemImageFetcher {

    private struct ItemURLContainer {
        let item: CDItem
        let url: URL
    }

    private let validSchemas = ["http", "https", "file"]

    func itemURL(_ item: CDItem) {
        Task(priority: .userInitiated) {
            var itemImageUrl: String?
            if let urlString = item.mediaThumbnail, let imgUrl = URL(string: urlString) {
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

            if let imageUrlString = itemImageUrl, let imageUrl = URL(string: imageUrlString) {
                await retrieve([ItemURLContainer(item: item, url: imageUrl)])
            } else {
                try await CDItem.addImageLink(item: item, imageLink: "data:null")
            }
        }
    }

    func itemImages() async throws {

        if let items = CDItem.itemsWithoutImageLink() {
            var itemUrlsToRetrieve = [ItemURLContainer]()
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
                    itemUrlsToRetrieve.append(ItemURLContainer(item: item, url: imageUrl))
                } else {
                    try await CDItem.addImageLink(item: item, imageLink: "data:null")
                }
            }
            await retrieve(itemUrlsToRetrieve)
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

extension ItemImageFetcher {

    private func retrieve(_ itemUrlContainers: [ItemURLContainer]) async {
        for itemUrlContainer in itemUrlContainers {
            let retrieveTask = Task { () -> KFCrossPlatformImage in
                let manager = KingfisherManager.shared
                let resource = ImageResource(downloadURL: itemUrlContainer.url)
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
                    try await CDItem.addImageLink(item: itemUrlContainer.item, imageLink: itemUrlContainer.url.absoluteString)
                } catch { }
            case .failure(let error as KingfisherError):
                switch error {
                case .processorError(reason: let reason):
                    print(reason)
                    switch reason {
                    case .processingFailed(processor: let processor, item: _):
                        if processor.identifier == SizeProcessor().identifier {
                            print("size failure")
                            do {
                                try await CDItem.addImageLink(item: itemUrlContainer.item, imageLink: "data:null")
                            } catch { }
                        }
                    }
                default:
                    break
                }
            case .failure(_):
                break
            }
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
