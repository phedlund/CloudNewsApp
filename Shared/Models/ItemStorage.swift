//
//  ItemStorage.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/3/21.
//

import Combine
import CoreData
import Foundation

class ItemStorage: NSObject, ObservableObject {
    var items = CurrentValueSubject<[CDItem], Never>([])
    private let itemFetchController: NSFetchedResultsController<CDItem>
    static let shared = ItemStorage()

    private let savePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext).eraseToAnyPublisher()
    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: NewsData.mainThreadContext).eraseToAnyPublisher()
    private let fetchRequest = CDItem.fetchRequest()

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(value: true)
        itemFetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: NewsData.mainThreadContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init()

        itemFetchController.delegate = self

        savePublisher
            .merge(with: syncPublisher)
            .sink { [weak self]  _ in
                guard let self = self else { return }
                do {
                    self.items.value = try NewsData.mainThreadContext.fetch(self.fetchRequest)
                } catch {
                    //
                }
            }
            .store(in: &cancellables)

        do {
            try itemFetchController.performFetch()
            items.value = itemFetchController.fetchedObjects ?? []
        } catch {
            print("Error: could not fetch items")
        }

    }
}

extension ItemStorage: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let items = controller.fetchedObjects as? [CDItem] else { return }
        for item in items {
            print("Item change \(item.changedValues())")
        }
        self.items.value = items
    }
}

class FeedStorage: NSObject, ObservableObject {
    var feeds = CurrentValueSubject<[CDFeed], Never>([])
    private let feedFetchController: NSFetchedResultsController<CDFeed>
    static let shared = FeedStorage()

    private override init() {
        let fetchRequest = CDFeed.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDFeed.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(value: true)
        feedFetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: NewsData.mainThreadContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init()

        feedFetchController.delegate = self

        do {
            try feedFetchController.performFetch()
            feeds.value = feedFetchController.fetchedObjects ?? []
        } catch {
            print("Error: could not fetch feeds")
        }

    }
}

extension FeedStorage: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let feeds = controller.fetchedObjects as? [CDFeed] else { return }
        for feed in feeds {
            print("Feed change \(feed.changedValues())")
        }
        self.feeds.value = feeds
    }
}

class FolderStorage: NSObject, ObservableObject {
    var folders = CurrentValueSubject<[CDFolder], Never>([])
    private let folderFetchController: NSFetchedResultsController<CDFolder>
    static let shared = FolderStorage()

    private override init() {
        let fetchRequest = CDFolder.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDFolder.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(value: true)
        folderFetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: NewsData.mainThreadContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init()

        folderFetchController.delegate = self

        do {
            try folderFetchController.performFetch()
            folders.value = folderFetchController.fetchedObjects ?? []
        } catch {
            print("Error: could not fetch feeds")
        }

    }
}

extension FolderStorage: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let folders = controller.fetchedObjects as? [CDFolder] else { return }
        for folder in folders {
            print("Folder change \(folder.changedValues())")
        }
        self.folders.value = folders
    }
}
