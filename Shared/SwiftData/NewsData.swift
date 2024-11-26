//
//  NewsData.swift
//  CloudNewsApp2
//
//  Created by Peter Hedlund on 6/10/23.
//

import Foundation
import SwiftData

//class NewsData {
//
//    let newsSchema = Schema([
//            Feeds.self,
//            Feed.self,
//            Folder.self,
//            Item.self,
//            Read.self,
//            Unread.self,
//            Starred.self,
//            Unstarred.self
//        ])
//
//    var container: ModelContainer?
//
//    init() {
//        do {
//            container = try ModelContainer(for: newsSchema, configurations: ModelConfiguration())
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
//
//    func resetDatabase() {
//        //
//    }
//}

@ModelActor
public actor NewsDataModelActor: NewsDatabase {
    public func fetch<T: Sendable>(_ descriptor: @Sendable @escaping () -> FetchDescriptor<T>) async throws -> [T] where T : PersistentModel {
        return [T]()
    }

    public func delete<T>(where predicate: Predicate<T>?) async throws where T : PersistentModel {
        try self.modelContext.delete(model: T.self, where: predicate)
    }

    public func delete<T>(_ model: T) async where T : PersistentModel {
        self.modelContext.delete(model)
    }

    public func delete(_ indentifier: PersistentIdentifier) async {
        await delete(self.modelContext.model(for: indentifier))
    }

    public func deleteAll<T>( _ model: T.Type) async where T : PersistentModel {
        try? self.modelContext.delete(model: T.self)
    }

    public func save() async throws {
        try self.modelContext.save()
    }

    public func insert<T>(_ model: T) async where T : PersistentModel {
        self.modelContext.insert(model)
        try? await save()
    }

    // Function to get a feed by ID
    func model(by id: PersistentIdentifier) async throws -> (any PersistentModel)? {
        return modelContext.model(for: id)
    }

    func allModels<T: PersistentModel>() async throws -> [T] {
        let fetchRequest = FetchDescriptor<T>()
        return try modelContext.fetch(fetchRequest)
    }

    func allModelIds<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) async throws -> [PersistentIdentifier] {
        try modelContext.fetchIdentifiers(descriptor)
    }

    public func fetchData<T: PersistentModel>(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) throws -> [T] {
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        let list: [T] = try modelContext.fetch(fetchDescriptor)
        return list
    }

    public func fetchCount<T: PersistentModel>(predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) throws -> Int {
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        let count = try modelContext.fetchCount(fetchDescriptor)
        return count
    }

    public func itemCount() async throws -> Int {
        let fetchDescriptor = FetchDescriptor<Item>()
        let count = try modelContext.fetchCount(fetchDescriptor)
        return count
    }

    public func delete<T: PersistentModel>(_ model: T.Type, where predicate: Predicate<T>) async throws {
        try modelContext.delete(model: T.self, where: predicate)
        try await save()
    }

    public func fetchItemId(by id: PersistentIdentifier) async throws -> Int64? {
        let model = modelContext.model(for: id)
        if let model = model as? Read {
            return model.itemId
        }
        if let model = model as? Unread {
            return model.itemId
        }
        if let model = model as? Starred {
            return model.itemId
        }
        if let model = model as? Unstarred {
            return model.itemId
        }
        return nil
    }
}

extension NewsDataModelActor {

    func maxLastModified() async -> Int64 {
        var result: Int64 = 0
        do {
            let items: [Item] = try fetchData()
            result = Int64(items.map( { $0.lastModified }).max()?.timeIntervalSince1970 ?? 0)
        } catch { }
        return result
    }

    func allFolders() throws -> [Folder]? {
        let sortDescriptor = SortDescriptor<Folder>(\.id, order: .forward)
//        let descriptor = FetchDescriptor<Folder>(sortBy: [sortDescriptor])
        let folders: [Folder] = try fetchData(sortBy: [sortDescriptor])
        return folders
//        do {
//            return try modelContext.fetch(descriptor)
//        } catch let error as NSError {
//            print("Could not fetch \(error), \(error.userInfo)")
//        }
//        return nil
    }

    func folder(id: Int64) -> Folder? {
        let predicate = #Predicate<Folder>{ $0.id == id }

        var descriptor = FetchDescriptor<Folder>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try modelContext.fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func folder(name: String) -> Folder? {
        let predicate = #Predicate<Folder>{ $0.name == name }
        var descriptor = FetchDescriptor<Folder>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try modelContext.fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func deleteFolder(id: Int64) async throws {
        do {
            try await delete(Folder.self, where: #Predicate { $0.id == id })
        } catch {
            throw DatabaseError.folderErrorDeleting
        }
    }

    func allFeeds() -> [Feed]? {
        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        //        let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned)
        let descriptor = FetchDescriptor<Feed>(sortBy: [idSortDescriptor])
        do {
            return try modelContext.fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feed(id: Int64) -> Feed? {
        let predicate = #Predicate<Feed>{ $0.id == id }

        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try modelContext.fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feedsInFolder(folder: Int64) -> [Feed]? {
        let predicate = #Predicate<Feed>{ $0.folderId == folder }

        let idSortDescriptor = SortDescriptor<Feed>(\.id, order: .forward)
        //let pinnedSortDescriptor = SortDescriptor<Feed>(\.pinned, order: .forward)
        let descriptor = FetchDescriptor<Feed>(predicate: predicate, sortBy: [idSortDescriptor])
        do {
            return try modelContext.fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func feedIdsInFolder(folder: Int64) -> [Int64]? {
        if let feeds = feedsInFolder(folder: folder) {
            return feeds.map { $0.id }
        }
        return nil
    }

    func deleteFeed(id: Int64) async throws {
        do {
            try await delete(Feed.self, where: #Predicate { $0.id == id } )
        } catch {
            throw DatabaseError.feedErrorDeleting
        }
    }

    func deleteItems(with feedId: Int64) async throws {
        do {
            try await delete(Item.self, where: #Predicate { $0.feedId == feedId } )
        } catch {
            throw DatabaseError.itemErrorDeleting
        }
    }

    func itemsNewerThan(date: Date) -> [Item]? {
        let predicate = #Predicate<Item>{ $0.lastModified > date }
        let descriptor = FetchDescriptor<Item>(predicate: predicate)
        do {
            return try modelContext.fetch(descriptor)
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    func update<T>(_ persistentIdentifier: PersistentIdentifier, keypath: ReferenceWritableKeyPath<Item, T>, to value: T) async throws {
        guard let model = try? await model(by: persistentIdentifier) as? Item else {
            // Error handling
            return
        }
        model[keyPath: keypath] = value
        try? await save()
    }

}
