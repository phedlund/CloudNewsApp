//
//  NewsModelActor.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/17/25.
//

import Foundation
import SwiftData
import SwiftSoup
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public let schema = Schema([
    Node.self,
    Feeds.self,
    Feed.self,
    Folder.self,
    Item.self,
    Read.self,
    Unread.self,
    Starred.self,
    Unstarred.self,
    FavIcon.self
])

struct ExistingItemMedia: Sendable {
    let thumbnailURL: URL?
    let image: Data?
    let thumbnail: Data?
}

@ModelActor
actor NewsModelActor: Sendable {

    private var modelContext: ModelContext { modelExecutor.modelContext }

    func save() async throws {
        try modelContext.save()
    }

    func fetchData<T: PersistentModel>(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) throws -> [T] {
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        let list: [T] = try modelContext.fetch(fetchDescriptor)
        return list
    }
    
    func insert<T>(_ model: T) async where T: PersistentModel {
        modelContext.insert(model)
        try? await save()
    }

    func insertNode(nodeDTO: NodeDTO) async {
        let nodeToStore = Node(item: nodeDTO)
        modelContext.insert(nodeToStore)
    }

    func insertFeed(feedDTO: FeedDTO) async {
        let feedToStore = await Feed(item: feedDTO)
        modelContext.insert(feedToStore)
    }

    func insertItem(itemDTO: ItemDTO) async {
        let itemToStore = await Item(item: itemDTO)
        modelContext.insert(itemToStore)
    }

    func insertFavIcon(itemDTO: FavIconDTO) async {
        let itemToStore = await FavIcon(item: itemDTO)
        modelContext.insert(itemToStore)
    }

    func delete<T: PersistentModel>(model: T.Type, where predicate: Predicate<T>? = nil) async throws {
        try modelContext.delete(model: model, where: predicate)
    }

    func feedIdsInFolder(folder: Int64) -> [Int64]? {
        let predicate = #Predicate<Feed>{ $0.folderId == folder }
        
        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        let descriptor = FetchDescriptor<Feed>(predicate: predicate, sortBy: [idSortDescriptor])
        do {
            return try modelContext.fetch(descriptor).map( { $0.id })
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func folderName(id: Int64) async -> String? {
        let predicate = #Predicate<Folder>{ $0.id == id }

        var descriptor = FetchDescriptor<Folder>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first?.name
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feedPrefersWeb(id: Int64) async -> Bool {
        let predicate = #Predicate<Feed>{ $0.id == id }
        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results = try modelContext.fetch(descriptor)
            return results.first?.preferWeb ?? false
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
            return false
        }
    }

    func fetchCount<T: PersistentModel>(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) throws -> Int {
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        let count = try modelContext.fetchCount(fetchDescriptor)
        return count
    }

    func fetchUnreadIds(descriptor: FetchDescriptor<Item>) async throws -> [PersistentIdentifier] {
        var result = [PersistentIdentifier]()
        let items = try modelContext.fetch(descriptor)
        let ids: [PersistentIdentifier] = items.map(\.persistentModelID)
        result.append(contentsOf: ids)
        return result
    }

    func fetchItemId(by id: PersistentIdentifier) async throws -> Int64? {
        let model = modelContext.model(for: id)
        if let model = model as? Read {
            return model.itemId
        }
        if let model = model as? Unread {
            return model.itemId
        }
        return nil
    }

    func allModelIds<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) async throws -> [PersistentIdentifier] {
        try modelContext.fetchIdentifiers(descriptor)
    }
    
    func maxLastModified() async -> Int64 {
        var result: Int64 = 0
        do {
            let items: [Item] = try fetchData()
            result = Int64(items.map( { $0.lastModified }).max()?.timeIntervalSince1970 ?? 0)
        } catch { }
        return result
    }
    
    func deleteNode(id: String) async throws {
        do {
            try modelContext.delete(model: Node.self, where: #Predicate { $0.id == id } )
        } catch(let error) {
            print(error.localizedDescription)
            throw DatabaseError.nodeErrorDeleting
        }
    }

    func deleteFolder(id: Int64) async throws {
        do {
            try modelContext.delete(model: Folder.self, where: #Predicate { $0.id == id })
        } catch {
            throw DatabaseError.folderErrorDeleting
        }
    }

    func deleteFeed(id: Int64) async throws {
        do {
            try modelContext.delete(model: Feed.self, where: #Predicate { $0.id == id } )
        } catch {
            throw DatabaseError.feedErrorDeleting
        }
    }

    func deleteItems(with feedId: Int64) async throws {
        do {
            try modelContext.delete(model: Item.self, where: #Predicate { $0.feedId == feedId } )
        } catch {
            throw DatabaseError.itemErrorDeleting
        }
    }

    func update<T>(_ persistentIdentifier: PersistentIdentifier, keypath: ReferenceWritableKeyPath<Item, T>, to value: T) async throws -> Int64? {
        guard let model = modelContext.model(for: persistentIdentifier) as? Item else {
            // Error handling
            return nil
        }
        model[keyPath: keypath] = value
        return model.id
    }

    func itemMediaThumbnail(for itemId: PersistentIdentifier) async -> String? {
        guard let item = modelContext.model(for: itemId) as? Item else { return nil }
        return item.mediaThumbnail
    }

    func itemBody(for itemId: PersistentIdentifier) async -> String? {
        guard let item = modelContext.model(for: itemId) as? Item else { return nil }
        return item.body
    }

    func itemUrl(for itemId: PersistentIdentifier) async -> String? {
        guard let item = modelContext.model(for: itemId) as? Item else { return nil }
        return item.url
    }

    func pruneFeeds(serverFeedIds: [Int64]) async throws {
        let fetchRequest = FetchDescriptor<Feed>()
        let feeds: [Feed] = try modelContext.fetch(fetchRequest)
        for feed in feeds {
            if !serverFeedIds.contains(feed.id) {
                try await deleteItems(with: feed.id)
                let type = NodeType.feed(id: feed.id)
                try await deleteNode(id: type.description)
                modelContext.delete(feed)
            }
        }
    }

    func pruneFolders(serverFolderIds: [Int64]) async throws {
        let fetchRequest = FetchDescriptor<Folder>()
        let folders: [Folder] = try modelContext.fetch(fetchRequest)
        for folder in folders {
            if !serverFolderIds.contains(folder.id) {
                modelContext.delete(folder)
            }
        }
    }

    func existingMediaMap(for ids: Set<Int64>) async throws -> [Int64: ExistingItemMedia] {
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { ids.contains($0.id) })
        let items = try modelContext.fetch(descriptor)
        var map = [Int64: ExistingItemMedia]()
        map.reserveCapacity(items.count)
        for it in items {
            map[it.id] = ExistingItemMedia(thumbnailURL: it.thumbnailURL, image: it.image, thumbnail: it.thumbnail)
        }
        return map
    }

    func buildAndInsert(from dto: ItemDTO, existing: ExistingItemMedia?) async {
        let displayTitle = await plainSummary(raw: dto.title)

        var summary = ""
        if let body = dto.body {
            summary = body
        } else if let mediaDescription = dto.mediaDescription {
            summary = mediaDescription
        }
        let displayBody = await plainSummary(raw: summary)

        let clipLength = 50
        var dateLabelText = ""
        await dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: dto.pubDate))

        if let itemAuthor = dto.author, !itemAuthor.isEmpty {
            if !dateLabelText.isEmpty {
                dateLabelText.append(" | ")
            }
            if itemAuthor.count > clipLength {
                dateLabelText.append(contentsOf: itemAuthor.filter({ !$0.isNewline }).prefix(clipLength))
                dateLabelText.append(String(0x2026))
            } else {
                dateLabelText.append(itemAuthor)
            }
        }

        var itemImageUrl: URL? = existing?.thumbnailURL
//        var imageData: Data? = existing?.image
//        var thumbnailData: Data? = existing?.thumbnail

        if existing == nil {
            let validSchemas = ["http", "https", "file"]

            func internalUrl(_ urlString: String?) async -> URL? {
                if let urlString, let url = URL(string: urlString) {
                    do {
                        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
                        if let html = String(data: data, encoding: .utf8) {
                            let doc: Document = try SwiftSoup.parse(html)
                            if let meta = try doc.head()?.select("meta[property=og:image]").first() as? Element {
                                let ogImage = try meta.attr("content")
                                return URL(string: ogImage)
                            } else if let meta = try doc.head()?.select("meta[property=twitter:image]").first() as? Element {
                                let twImage = try meta.attr("content")
                                return URL(string: twImage)
                            }
                        }
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                return nil
            }

            if let urlString = dto.mediaThumbnail, let imgUrl = URL(string: urlString) {
                itemImageUrl = imgUrl
            } else if let summary = dto.body {
                do {
                    let doc: Document = try SwiftSoup.parse(summary)
                    let srcs: Elements = try doc.select("img[src]")
                    let images = try srcs.array().map({ try $0.attr("src") })
                    let filteredImages = images.filter({ validSchemas.contains(String($0.prefix(4))) })
                    if let urlString = filteredImages.first, let imgUrl = URL(string: urlString) {
                        itemImageUrl = imgUrl
                    } else {
                        itemImageUrl = await internalUrl(dto.url)
                    }
                } catch Exception.Error(_, let message) {
                    print(message)
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                itemImageUrl = await internalUrl(dto.url)
            }

//            if let itemImageUrl {
//                do {
//                    let (data, _) = try await URLSession.shared.data(from: itemImageUrl)
//                    imageData = data
//    #if os(macOS)
//                    if let uiImage = NSImage(data: data) {
//                        thumbnailData = uiImage.tiffRepresentation
//                    }
//    #else
//                    if let uiImage = UIImage(data: data) {
//                        let displayScale = UITraitCollection.current.displayScale
//                        let thumbnailSize = CGSize(width: 48 * displayScale, height: 48 * displayScale)
//                        thumbnailData = await uiImage.byPreparingThumbnail(ofSize: thumbnailSize)?.pngData()
//                    }
//    #endif
//                } catch {
//                    print("Error fetching data: \(error)")
//                }
//            }
        }

        let item = Item(author: dto.author,
                        body: dto.body,
                        contentHash: dto.contentHash,
                        displayBody: displayBody,
                        displayTitle: displayTitle,
                        dateFeedAuthor: dateLabelText,
                        enclosureLink: dto.enclosureLink,
                        enclosureMime: dto.enclosureMime,
                        feedId: dto.feedId,
                        fingerprint: dto.fingerprint,
                        guid: dto.guid,
                        guidHash: dto.guidHash,
                        id: dto.id,
                        lastModified: dto.lastModified,
                        mediaThumbnail: dto.mediaThumbnail,
                        mediaDescription: dto.mediaDescription,
                        pubDate: dto.pubDate,
                        rtl: dto.rtl,
                        starred: dto.starred,
                        title: dto.title,
                        unread: dto.unread,
                        updatedDate: dto.updatedDate,
                        url: dto.url,
                        thumbnailURL: itemImageUrl,
                        image: nil,
                        thumbnail: nil)

        modelContext.insert(item)
    }
}
