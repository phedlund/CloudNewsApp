//
//  ImagePrefetchManager.swift
//  CloudNews
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
class ImagePrefetchManager: ObservableObject {
    static let shared = ImagePrefetchManager()

    private var cache = NSCache<NSURL, SystemImage>()
    private var prefetchTasks: [URL: Task<Void, Never>] = [:]
    private let session: URLSession

    init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024

        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        session = URLSession(configuration: config)
    }

    func prefetchImages(for items: [Item], startingAt index: Int, count: Int = 20) {
        let endIndex = min(index + count, items.count)
        let itemsToPreload = items[index..<endIndex]

        for item in itemsToPreload {
            guard let url = item.thumbnailURL else { continue }

            if cache.object(forKey: url as NSURL) != nil { continue }

            if prefetchTasks[url] != nil { continue }

            let task = Task {
                await prefetchImage(url: url)
            }
            prefetchTasks[url] = task
        }
    }

    func getImage(for url: URL) -> SystemImage? {
        return cache.object(forKey: url as NSURL)
    }

    private func prefetchImage(url: URL) async {
        defer { prefetchTasks.removeValue(forKey: url) }

        do {
            let (data, _) = try await session.data(from: url)

            let decompressed = await Task.detached(priority: .utility) {
                ImageUtils.decompressImage(data: data)
            }.value

            if let decompressed = decompressed {
                cache.setObject(decompressed, forKey: url as NSURL)
            }
        } catch {
            //
        }
    }

    func cancelPrefetch(for url: URL) {
        prefetchTasks[url]?.cancel()
        prefetchTasks.removeValue(forKey: url)
    }

    func clearCache() {
        cache.removeAllObjects()
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()
    }
}
