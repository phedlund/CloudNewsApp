//
//  NewsDataModelActor.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/13/24.
//

import Foundation
import SwiftData
import SwiftUI

public protocol NewsDatabase: Sendable {
    func delete<T: Sendable>(_ model: T) async where T: PersistentModel
    func insert<T: Sendable>(_ model: T) async where T: PersistentModel
    func save() async throws
    func fetch<T>(_ descriptor: @Sendable @escaping () -> FetchDescriptor<T>) async throws -> [T] where T: PersistentModel

    func delete<T: PersistentModel>(where predicate: Predicate<T>?) async throws
}

public extension NewsDatabase {
    func fetch<T: PersistentModel>(where predicate: Predicate<T>?, sortBy: [SortDescriptor<T>]) async throws -> [T] {
        try await self.fetch(T.self, predicate: predicate, sortBy: sortBy)
    }

    func fetch<T: PersistentModel>(_ predicate: Predicate<T>, sortBy: [SortDescriptor<T>] = []) async throws -> [T] {
        try await self.fetch(where: predicate, sortBy: sortBy)
    }

    func fetch<T: PersistentModel>(_: T.Type, predicate: Predicate<T>? = nil, sortBy: [SortDescriptor<T>] = []) async throws -> [T] {
        try await self.fetch(where: predicate, sortBy: sortBy)
    }

    func delete<T: PersistentModel>(model _: T.Type, where predicate: Predicate<T>? = nil) async throws {
        try await self.delete(where: predicate)
    }
}

struct DefaultDatabase: NewsDatabase {
    func fetch<T>(_ descriptor: @escaping @Sendable () -> FetchDescriptor<T>) async throws -> [T] where T : PersistentModel {
        assertionFailure("No Database Set.")
        throw NotImplmentedError.instance
    }
    
    func delete<T>(where predicate: Predicate<T>?) async throws where T : PersistentModel {
        assertionFailure("No Database Set.")
    }
    
    struct NotImplmentedError: Error {
        static let instance = NotImplmentedError()
    }

    static let instance = DefaultDatabase()

    func delete(_: some PersistentModel) async {
        assertionFailure("No Database Set.")
    }

    func insert(_: some PersistentModel) async {
        assertionFailure("No Database Set.")
    }

    func save() async throws {
        assertionFailure("No Database Set.")
        throw NotImplmentedError.instance
    }
}

public struct SharedDatabase {
    nonisolated(unsafe) public static let shared: SharedDatabase = .init()

    public let schema = Schema([
        Node.self,
        Feeds.self,
        Feed.self,
        Folder.self,
        Item.self,
        Read.self,
        Unread.self,
        Starred.self,
        Unstarred.self
    ])

    public let modelContainer: ModelContainer
    public let database: NewsDatabase

    private init(modelContainer: ModelContainer? = nil, database: (any NewsDatabase)? = nil) {
        let modelContainer = try! ModelContainer(for: schema)
        self.modelContainer = modelContainer
        self.database = database ?? BackgroundNewsDatabase(modelContainer: modelContainer)
    }
}

final public class BackgroundNewsDatabase: NewsDatabase {

    private actor DatabaseContainer {
        private let factory: @Sendable () -> any NewsDatabase
        private var wrappedTask: Task<any NewsDatabase, Never>?

        fileprivate init(factory: @escaping @Sendable () -> any NewsDatabase) {
            self.factory = factory
        }

        fileprivate var database: any NewsDatabase {
            get async {
                if let wrappedTask {
                    return await wrappedTask.value
                }
                let task = Task {
                    factory()
                }
                self.wrappedTask = task
                return await task.value
            }
        }
    }

    private let container: DatabaseContainer

    private var database: any NewsDatabase {
        get async {
            await container.database
        }
    }

    convenience init(modelContainer: ModelContainer) {
        self.init {
            return NewsDataModelActor(modelContainer: modelContainer)
        }
    }

    internal init(_ factory: @Sendable @escaping () -> any NewsDatabase) {
        self.container = .init(factory: factory)
    }

    public func delete<T>(_ model: T) async where T : Sendable, T : PersistentModel {
        try? await self.database.delete(model: T.self)
    }

    public func delete(where predicate: Predicate<some PersistentModel>?) async throws {
        return try await self.database.delete(where: predicate)
    }

    public func fetch<T>(_ descriptor: @escaping @Sendable () -> FetchDescriptor<T>) async throws -> [T] where T : PersistentModel {
        return try await self.database.fetch(descriptor)
    }

    public func insert(_ model: some PersistentModel) async { }

    public func save() async throws {
        return try await self.database.save()
    }
}


private struct DatabaseKey: EnvironmentKey {
    static var defaultValue: any NewsDatabase {
        DefaultDatabase.instance
    }
}

public extension EnvironmentValues {
    var database: any NewsDatabase {
        get {
            self[DatabaseKey.self]
        }
        set {
            self[DatabaseKey.self] = newValue
        }
    }
}

public extension Scene {
    func database(_ database: any NewsDatabase) -> some Scene {
        self.environment(\.database, database)
    }
}
