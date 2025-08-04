//
//  NewsModelActor.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/17/25.
//

import Foundation
import SwiftData

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

public struct StarredParameter: Sendable {
    var feedId: Int64
    var guidHash: String
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

}
