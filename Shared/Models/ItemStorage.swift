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

    private override init() {
        let fetchRequest = CDItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CDItem.id, ascending: false)]
        fetchRequest.predicate = NSPredicate(value: true)
        itemFetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: NewsData.mainThreadContext,
            sectionNameKeyPath: nil,
            cacheName: nil)

        super.init()

        itemFetchController.delegate = self

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
        self.items.value = items
    }
}
