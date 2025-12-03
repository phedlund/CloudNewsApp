import Foundation
import SwiftData

// MARK: - Data Migration Manager

class DataMigrationManager {

    /// Enum to track which migrations have been completed
    enum Migration: String, CaseIterable {
        case nodePinnedValues = "NodePinnedMigrationComplete"
        // Add future migrations here:
        // case feedIconUpdate = "FeedIconUpdateComplete"
        // case itemBodyCleanup = "ItemBodyCleanupComplete"

        var isComplete: Bool {
            UserDefaults.standard.bool(forKey: self.rawValue)
        }

        func markComplete() {
            UserDefaults.standard.set(true, forKey: self.rawValue)
            print("✅ Migration '\(self.rawValue)' marked as complete")
        }

        func reset() {
            UserDefaults.standard.removeObject(forKey: self.rawValue)
            print("🔄 Migration '\(self.rawValue)' reset")
        }
    }

    /// Run all pending migrations
    @MainActor
    static func runPendingMigrations(modelContext: ModelContext) async throws {
        print("🔍 Checking for pending migrations...")

        // Run each migration if not already complete
        for migration in Migration.allCases {
            if !migration.isComplete {
                print("⏳ Running migration: \(migration.rawValue)")
                try await runMigration(migration, modelContext: modelContext)
                migration.markComplete()
            } else {
                print("⏭️ Skipping completed migration: \(migration.rawValue)")
            }
        }

        print("✅ All migrations complete")
    }

    /// Execute a specific migration
    @MainActor
    private static func runMigration(_ migration: Migration, modelContext: ModelContext) async throws {
        switch migration {
        case .nodePinnedValues:
            try await migrateNodePinnedValues(modelContext: modelContext)
        // Add future migration cases here:
        // case .feedIconUpdate:
        //     try await migrateFeedIcons(modelContext: modelContext)
        // case .itemBodyCleanup:
        //     try await cleanupItemBodies(modelContext: modelContext)
        }
    }

    /// Reset all migrations (useful for testing)
    @MainActor
    static func resetAllMigrations() {
        for migration in Migration.allCases {
            migration.reset()
        }
        print("🔄 All migration flags reset")
    }

    /// Reset a specific migration (useful for testing)
    @MainActor
    static func resetMigration(_ migration: Migration) {
        migration.reset()
    }
}

// MARK: - Individual Migration Implementations

extension DataMigrationManager {

    /// Migration: Set pinned values for nodes based on their type
    @MainActor
    private static func migrateNodePinnedValues(modelContext: ModelContext) async throws {
        print("🔄 Starting Node pinned value migration...")

        // Fetch all nodes
        let descriptor = FetchDescriptor<Node>()
        let nodes = try modelContext.fetch(descriptor)
        print("📊 Found \(nodes.count) nodes to migrate")

        var updatedCount = 0
        for node in nodes {
            let oldPinned = node.pinned

            // Set pinned value based on NodeType
            switch node.type {
            case .all:
                node.pinned = 5
                print("✅ Node '\(node.title)' (type: .all) - pinned: \(oldPinned) → 5")
            case .unread:
                node.pinned = 4
                print("✅ Node '\(node.title)' (type: .unread) - pinned: \(oldPinned) → 4")
            case .starred:
                node.pinned = 3
                print("✅ Node '\(node.title)' (type: .starred) - pinned: \(oldPinned) → 3")
            case .folder(let id):
                node.pinned = 2
                print("✅ Node '\(node.title)' (type: .folder(\(id))) - pinned: \(oldPinned) → 2")
            case .feed(let id):
                print("ℹ️ Node '\(node.title)' (type: .feed(\(id))) - pinned: \(oldPinned) (unchanged)")
            case .empty:
                print("ℹ️ Node '\(node.title)' (type: .empty) - pinned: \(oldPinned) (unchanged)")
            }

            if oldPinned != node.pinned {
                updatedCount += 1
            }
        }

        // Save changes
        try modelContext.save()
        print("💾 Node pinned migration complete - updated \(updatedCount) nodes")
    }

    // MARK: - Future Migration Examples

    // Example of a future migration:
    // @MainActor
    // private static func migrateFeedIcons(modelContext: ModelContext) async throws {
    //     print("🔄 Starting Feed icon migration...")
    //
    //     let descriptor = FetchDescriptor<Feed>()
    //     let feeds = try modelContext.fetch(descriptor)
    //     print("📊 Found \(feeds.count) feeds to migrate")
    //
    //     for feed in feeds {
    //         // Your migration logic here
    //         // feed.iconData = await fetchIcon(feed.url)
    //     }
    //
    //     try modelContext.save()
    //     print("💾 Feed icon migration complete")
    // }

    // @MainActor
    // private static func cleanupItemBodies(modelContext: ModelContext) async throws {
    //     print("🔄 Starting Item body cleanup migration...")
    //
    //     let descriptor = FetchDescriptor<Item>()
    //     let items = try modelContext.fetch(descriptor)
    //     print("📊 Found \(items.count) items to process")
    //
    //     var cleanedCount = 0
    //     for item in items {
    //         if let body = item.body, body.contains("old-pattern") {
    //             item.body = body.replacingOccurrences(of: "old-pattern", with: "new-pattern")
    //             cleanedCount += 1
    //         }
    //     }
    //
    //     try modelContext.save()
    //     print("💾 Item body cleanup complete - cleaned \(cleanedCount) items")
    // }
}

// MARK: - Usage in CloudNewsApp.swift
//
// Update your app to use the migration manager:
//
// struct CloudNewsApp: App {
//     private let container: ModelContainer
//     // ... other properties
//
//     init() {
//         do {
//             container = try ModelContainer(for: schema)
//             self.modelActor = NewsModelActor(modelContainer: container)
//             self.newsModel = NewsModel(modelContainer: container)
//             self.syncManager = SyncManager(modelContainer: container)
//             ContentBlocker.shared.rules(completion: { _ in })
//             let _ = CssProvider.shared.css()
//             migrateKeychain()
//         } catch {
//             fatalError("Failed to create container")
//         }
//     }
//
//     var body: some Scene {
//         WindowGroup {
//             ContentView()
//                 .environment(newsModel)
//                 .environment(syncManager)
//                 .task {
//                     // Run all pending migrations once when the app starts
//                     let context = ModelContext(container)
//                     try? await DataMigrationManager.runPendingMigrations(modelContext: context)
//                 }
//         }
//         .modelContainer(container)
//         // ... rest of your scenes
//     }
// }
//
// MARK: - Adding New Migrations
//
// To add a new migration in the future:
//
// 1. Add a new case to the Migration enum:
//    case myNewMigration = "MyNewMigrationComplete"
//
// 2. Add the case to the switch statement in runMigration():
//    case .myNewMigration:
//        try await migrateMyNewFeature(modelContext: modelContext)
//
// 3. Implement the migration method:
//    @MainActor
//    private static func migrateMyNewFeature(modelContext: ModelContext) async throws {
//        // Your migration logic here
//    }
//
// The migration will automatically run once on the next app launch!
