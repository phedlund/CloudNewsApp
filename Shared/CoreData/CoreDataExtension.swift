//
//  CoreDataExtension.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {

    /// Executes the given `NSBatchUpdateRequest` and directly merges the changes to bring the given managed object context up to date.
    ///
    /// - Parameter batchUpdateRequest: The `NSBatchUpdateRequest` to execute.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    public func executeAndMergeChanges(using batchUpdateRequest: NSBatchUpdateRequest) throws {
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        let result = try execute(batchUpdateRequest) as? NSBatchUpdateResult
        let changes: [AnyHashable: Any] = [NSUpdatedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
    }

    /// Executes the given `NSBatchDeleteRequest` and directly merges the changes to bring the given managed object context up to date.
    ///
    /// - Parameter batchDeleteRequest: The `NSBatchDeleteRequest` to execute.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    public func executeAndMergeChanges(using batchDeleteRequest: NSBatchDeleteRequest) throws {
        batchDeleteRequest.resultType = .resultTypeObjectIDs
        let result = try execute(batchDeleteRequest) as? NSBatchDeleteResult
        let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: result?.result as? [NSManagedObjectID] ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
    }
}

extension NSFetchRequestResult where Self: NSManagedObject {

    @discardableResult
    public static func delete(ids: [Int32], in context: NSManagedObjectContext) -> NSBatchDeleteResult? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
        let predicate = NSPredicate(format: "id IN %@", ids)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        do {
            let result = try context.execute(deleteRequest)
            try context.save()
            return result as? NSBatchDeleteResult
        } catch let error as NSError {
            print("Could not perform deletion \(error), \(error.userInfo)")
            return nil
        }
    }

    @discardableResult
    public static func deleteItemIds(itemIds: [Int32], in context: NSManagedObjectContext) -> NSBatchDeleteResult? {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: Self.self))
        let predicate = NSPredicate(format: "itemId IN %@", itemIds)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        do {
            let result = try context.execute(deleteRequest)
//            try context.save()
            return result as? NSBatchDeleteResult
        } catch let error as NSError {
            print("Could not perform deletion \(error), \(error.userInfo)")
            return nil
        }
    }

}
