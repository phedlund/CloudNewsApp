//
//  NewsData.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import CoreData
import OSLog

class NewsData {

    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: NewsData.self))

    static let shared = NewsData()

    private let inMemory: Bool
    private var notificationToken: NSObjectProtocol?
    private var lastToken: NSPersistentHistoryToken?

    private init(inMemory: Bool = false) {
        self.inMemory = inMemory
        retrieveHistoryToken()
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { _ in
            self.logger.debug("Received a persistent store remote change notification.")
            Task {
                await self.fetchPersistentHistory()
            }
        }
    }

    deinit {
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NewsData")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        container.viewContext.transactionAuthor = "viewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        return container
    }()

    private lazy var tokenFileURL: URL = {
        let url = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("NewsData", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch { }
        return url.appendingPathComponent("token", isDirectory: false).appendingPathExtension("dat")
    }()

    func newTaskContext() -> NSManagedObjectContext {
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.undoManager = nil
        return taskContext
    }

    func fetchPersistentHistory() async {
        do {
            try await fetchPersistentHistoryTransactionsAndChanges()
        } catch {
            logger.debug("\(error.localizedDescription)")
        }
    }

    private func fetchPersistentHistoryTransactionsAndChanges() async throws {
        let taskContext = newTaskContext()
        taskContext.name = "persistentHistoryContext"
        logger.debug("Start fetching persistent history changes from the store...")

        try await taskContext.perform {
            let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
            if let historyFetchRequest = NSPersistentHistoryTransaction.fetchRequest {
                historyFetchRequest.predicate = NSPredicate(format: "%K != %@", "author", "viewContext")
                changeRequest.fetchRequest = historyFetchRequest
            }
            let historyResult = try taskContext.execute(changeRequest) as? NSPersistentHistoryResult
            if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
               !history.isEmpty {
                self.mergePersistentHistoryChanges(from: history)
                return
            }

            self.logger.debug("No persistent history transactions found.")
            throw PBHError.databaseError(message: "History Change Error")
        }

        logger.debug("Finished merging history changes.")
    }

    private func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        self.logger.debug("Received \(history.count) persistent history transactions.")
        let viewContext = container.viewContext
        viewContext.perform {
            for transaction in history {
                print("Transaction author: \(transaction.author ?? "Unknown transaction author")")
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.storeHistoryToken(transaction.token)
            }
        }
    }

    private func storeHistoryToken(_ token: NSPersistentHistoryToken) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try data.write(to: tokenFileURL)
            lastToken = token
        } catch { }
    }

    private func retrieveHistoryToken() {
        do {
            let tokenData = try Data(contentsOf: tokenFileURL)
            lastToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
        } catch { }
    }

}
