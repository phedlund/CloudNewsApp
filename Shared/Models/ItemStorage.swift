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

extension NodeChange: Identifiable {

    var id: String {
        switch nodeType {
        case .empty:
            return "empty"
        case .all:
            return "all"
        case .starred:
            return "starred"
        case .folder(id: let id):
            return "folder_\(id)"
        case .feed(id: let id):
            return "feed\(id)"
        }
    }

}

extension NodeChange: Hashable {

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}

class ItemStorage: NSObject, ObservableObject {
    var changes = CurrentValueSubject<[NodeChange], Never>([])
    var folders = CurrentValueSubject<[CDFolder], Never>([])
    var feeds = CurrentValueSubject<[CDFeed], Never>([])
    static let shared = ItemStorage()

    private let willSavePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextWillSave, object: NewsData.shared.container.viewContext).eraseToAnyPublisher()
    private let didSavePublisher = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: NewsData.shared.container.viewContext).eraseToAnyPublisher()
    private let foldersFetchRequest = CDFolder.fetchRequest()
    private let feedsFetchRequest = CDFeed.fetchRequest()

    private var updatedObjects: Set<NSManagedObject>?
    private var deletedObjects: Set<NSManagedObject>?
    private var insertedObjects: Set<NSManagedObject>?

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        foldersFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        foldersFetchRequest.predicate = NSPredicate(value: true)

        feedsFetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        feedsFetchRequest.predicate = NSPredicate(value: true)

        super.init()

        do {
            self.folders.value = try NewsData.shared.container.viewContext.fetch(self.foldersFetchRequest)
            self.feeds.value = try NewsData.shared.container.viewContext.fetch(self.feedsFetchRequest)
        } catch {
            print("Error: could not fetch items")
        }

        willSavePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                self.updatedObjects = NewsData.shared.container.viewContext.updatedObjects
                self.insertedObjects = NewsData.shared.container.viewContext.insertedObjects
                var localChanges = Set<NodeChange>()
                if let updatedFolders = NewsData.shared.container.viewContext.updatedObjects.filter( { $0.entity == CDFolder.entity() }) as? Set<CDFolder> {
                    for updatedFolder in updatedFolders {
                        for change in updatedFolder.changedValues() {
                            localChanges.insert(NodeChange(nodeType: .folder(id: updatedFolder.id), key: change.key))
                        }
                    }
                }
                if let updatedFeeds = NewsData.shared.container.viewContext.updatedObjects.filter( { $0.entity == CDFeed.entity() }) as? Set<CDFeed> {
                    for updatedFeed in updatedFeeds {
                        for change in updatedFeed.changedValues() {
                            localChanges.insert(NodeChange(nodeType: .feed(id: updatedFeed.id), key: change.key))
                        }
                    }
                }
                if let updatedItems = NewsData.shared.container.viewContext.updatedObjects.filter( { $0.entity == CDItem.entity() }) as? Set<CDItem> {
                    for updatedItem in updatedItems {
                        for change in updatedItem.changedValues() {
                            if ["unread", "starred"].contains(change.key) {
                                localChanges.insert(NodeChange(nodeType: .feed(id: updatedItem.feedId), key: change.key))
                                if updatedItem.feedId > 0, let feed = CDFeed.feed(id: updatedItem.feedId), let folder = CDFolder.folder(id: feed.folderId) {
                                    localChanges.insert(NodeChange(nodeType: .folder(id: folder.id), key: change.key))
                                }
                                localChanges.insert(NodeChange(nodeType: .all, key: change.key))
                                localChanges.insert(NodeChange(nodeType: .starred, key: change.key))
                            }
                        }
                    }
                }
                if !localChanges.isEmpty {
                    self.changes.value = Array(localChanges)
                }
            }
            .store(in: &cancellables)

        didSavePublisher
            .sink { [weak self] notification in
                guard let self else { return }
                do {
                    if let deletedObjects = self.deletedObjects {
                        for deletedObject in deletedObjects {
                            switch deletedObject.entity {
                            case CDFolder.entity():
                                print("Deleted Folder")
                                self.folders.value = try NewsData.shared.container.viewContext.fetch(self.foldersFetchRequest)
                            case CDFeed.entity():
                                print("Deleted Feed")
                                self.feeds.value = try NewsData.shared.container.viewContext.fetch(self.feedsFetchRequest)
                            case CDItem.entity():
                                print("Deleted Item")
                                self.changes.value = [NodeChange(nodeType: .all, key: "unread")]
                            default:
                                break
                            }
                        }
                    }
                    if let insertedObjects = self.insertedObjects {
                        for insertedObject in insertedObjects {
                            switch insertedObject.entity {
                            case CDFolder.entity():
                                print("Inserted Folder")
                                self.folders.value = try NewsData.shared.container.viewContext.fetch(self.foldersFetchRequest)
                            case CDFeed.entity():
                                print("Inserted Feed")
                                self.feeds.value = try NewsData.shared.container.viewContext.fetch(self.feedsFetchRequest)
                            case CDItem.entity():
                                print("Inserted Item")
                                self.changes.value = [NodeChange(nodeType: .all, key: "unread")]
                            default:
                                break
                            }
                        }
                    }
                    if let updatedObjects = self.updatedObjects {
                        var localChanges = Set<NodeChange>()
                        for updatedObject in updatedObjects {
                            if updatedObject.entity == CDItem.entity(), let updatedItem = updatedObject as? CDItem {
                                for change in updatedItem.changedValues() {
                                    localChanges.insert(NodeChange(nodeType: .feed(id: updatedItem.feedId), key: change.key))
                                    if updatedItem.feedId > 0, let feed = CDFeed.feed(id: updatedItem.feedId), let folder = CDFolder.folder(id: feed.folderId) {
                                        localChanges.insert(NodeChange(nodeType: .folder(id: folder.id), key: change.key))
                                    }
                                    localChanges.insert(NodeChange(nodeType: .all, key: change.key))
                                    localChanges.insert(NodeChange(nodeType: .starred, key: change.key))
                                }
                            }
                        }
                        if !localChanges.isEmpty {
                            self.changes.value = Array(localChanges)
                        }
                    }
                } catch {
                    //
                }
            }
            .store(in: &cancellables)

        NewsManager.shared.syncSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.changes.value = [NodeChange(nodeType: .all, key: "unread")]
            }
            .store(in: &cancellables)

    }

}
