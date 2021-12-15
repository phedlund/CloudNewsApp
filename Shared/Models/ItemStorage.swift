//
//  ItemStorage.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/3/21.
//

import Combine
import CoreData
import Foundation

struct NodeChange {
    var nodeType: NodeType
    var key: String
}


class ItemStorage: NSObject, ObservableObject {
    var changes = CurrentValueSubject<[NodeChange], Never>([])
    var folders = CurrentValueSubject<[CDFolder], Never>([])
    var feeds = CurrentValueSubject<[CDFeed], Never>([])
    var items = CurrentValueSubject<[CDItem], Never>([])
    static let shared = ItemStorage()

    private let preferences = Preferences()
    private let willSavePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextWillSave, object: NewsData.mainThreadContext).eraseToAnyPublisher()
    private let didSavePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: NewsData.mainThreadContext).eraseToAnyPublisher()
    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: nil).eraseToAnyPublisher()
    private let foldersFetchRequest = CDFolder.fetchRequest()
    private let feedsFetchRequest = CDFeed.fetchRequest()
    private let itemsFetchRequest = CDItem.fetchRequest()

    private var updatedObjects: Set<NSManagedObject>?
    private var deletedObjects: Set<NSManagedObject>?
    private var insertedObjects: Set<NSManagedObject>?
    private var hideRead = false
    private var sortOldestFirst = false

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        foldersFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        foldersFetchRequest.predicate = NSPredicate(value: true)

        feedsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        feedsFetchRequest.predicate = NSPredicate(value: true)

        super.init()

        preferences.$hideRead
            .sink { [weak self] hideRead in
                self?.hideRead = hideRead
                self?.publishItems()
            }
            .store(in: &cancellables)

        preferences.$sortOldestFirst
            .sink { [weak self] sortOldestFirst in
                self?.sortOldestFirst = sortOldestFirst
                self?.publishItems()
            }
            .store(in: &cancellables)

        willSavePublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updatedObjects = NewsData.mainThreadContext.updatedObjects
                var localChanges = [NodeChange]()
                if let updatedFolders = NewsData.mainThreadContext.updatedObjects.filter( { $0.entity == CDFolder.entity() }) as? Set<CDFolder> {
                    for updatedFolder in updatedFolders {
                        for change in updatedFolder.changedValues() {
                            localChanges.append(NodeChange(nodeType: .folder(id: updatedFolder.id), key: change.key))
                        }
                    }
                }
                if let updatedFeeds = NewsData.mainThreadContext.updatedObjects.filter( { $0.entity == CDFeed.entity() }) as? Set<CDFeed> {
                    for updatedFeed in updatedFeeds {
                        for change in updatedFeed.changedValues() {
                            localChanges.append(NodeChange(nodeType: .feed(id: updatedFeed.id), key: change.key))
                        }
                    }
                }
                if let updatedItems = NewsData.mainThreadContext.updatedObjects.filter( { $0.entity == CDItem.entity() }) as? Set<CDItem> {
                    for updatedItem in updatedItems {
                        for change in updatedItem.changedValues() {
                            localChanges.append(NodeChange(nodeType: .feed(id: updatedItem.feedId), key: change.key))
                            if updatedItem.feedId > 0, let folder = CDFolder.folder(id: updatedItem.feedId) {
                                localChanges.append(NodeChange(nodeType: .folder(id: folder.id), key: change.key))
                            }
                            localChanges.append(NodeChange(nodeType: .all, key: change.key))
                            localChanges.append(NodeChange(nodeType: .starred, key: change.key))
                        }
                    }
                }
                if !localChanges.isEmpty {
                    self.changes.value = localChanges
                }
            }
            .store(in: &cancellables)

        Publishers.Merge(syncPublisher, didSavePublisher)
            .sink { [weak self] notification in
                guard let self = self else { return }
                do {
                    var objectIDs = [NSManagedObjectID]()
                    if let deletedObjects = self.deletedObjects {
                        objectIDs.append(contentsOf: deletedObjects.map( { $0.objectID } ))
                        for deletedObject in deletedObjects {
                            switch deletedObject.entity {
                            case CDFolder.entity():
                                print("Deleted Folder")
                                self.folders.value = try NewsData.mainThreadContext.fetch(self.foldersFetchRequest)
                            case CDFeed.entity():
                                print("Deleted Feed")
                                self.feeds.value = try NewsData.mainThreadContext.fetch(self.feedsFetchRequest)
                            case CDItem.entity():
                                print("Deleted Item")
                                self.publishItems()
                            default:
                                break
                            }
                        }
                    }
                    if let insertedObjects = self.insertedObjects {
                        objectIDs.append(contentsOf: insertedObjects.map( { $0.objectID } ))
                        for insertedObject in insertedObjects {
                            switch insertedObject.entity {
                            case CDFolder.entity():
                                print("Inserted Folder")
                                self.folders.value = try NewsData.mainThreadContext.fetch(self.foldersFetchRequest)
                            case CDFeed.entity():
                                print("Inserted Feed")
                                self.feeds.value = try NewsData.mainThreadContext.fetch(self.feedsFetchRequest)
                            case CDItem.entity():
                                print("Inserted Item")
                                self.publishItems()
                            default:
                                break
                            }
                        }
                    }
                } catch {
                    //
                }
            }
            .store(in: &cancellables)

        do {
            self.folders.value = try NewsData.mainThreadContext.fetch(self.foldersFetchRequest)
            self.feeds.value = try NewsData.mainThreadContext.fetch(self.feedsFetchRequest)
            self.publishItems()
        } catch {
            print("Error: could not fetch items")
        }
    }

    private func publishItems() {
        let sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.lastModified, ascending: sortOldestFirst ? true : false),
                               NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        let predicate = hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)
        itemsFetchRequest.sortDescriptors = sortDescriptors
        itemsFetchRequest.predicate = predicate
        do {
            self.items.value = try NewsData.mainThreadContext.fetch(self.itemsFetchRequest)
        } catch {
            //
        }
    }
}
