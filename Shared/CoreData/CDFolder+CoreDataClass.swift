//
//  CDFolder+CoreDataClass.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/31/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//
//

import Foundation
import CoreData

@objc(CDFolder)
public class CDFolder: NSManagedObject, FolderProtocol, Identifiable {

    static let entityName = "CDFolder"
    
    static func all() -> [CDFolder]? {
        let request : NSFetchRequest<CDFolder> = self.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "id", ascending: false)
        request.sortDescriptors = [sortDescription]
        var folderList = [CDFolder]()
        do {
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            for record in results {
                folderList.append(record)
            }
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return folderList
    }


    static func add(folders: [FolderProtocol], using context: NSManagedObjectContext) async throws {
        await context.perform {
            for folder in folders {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: CDFolder.entityName, into: context) as! CDFolder
                newRecord.id = Int32(folder.id)
                newRecord.name = folder.name
            }
        }
    }
    
    static func folder(id: Int32) -> CDFolder? {
        let request: NSFetchRequest<CDFolder> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func folder(name: String) -> CDFolder? {
        let request: NSFetchRequest<CDFolder> = self.fetchRequest()
        let predicate = NSPredicate(format: "name == %@", name)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }

    static func markExpanded(folderId: Int32, state: Bool) async throws {
        try await NewsData.shared.container.viewContext.perform {
            let request = CDFolder.fetchRequest()
            do {
                let predicate = NSPredicate(format:"id == %d", folderId)
                request.predicate = predicate
                let records = try NewsData.shared.container.viewContext.fetch(request)
                records.forEach({ folder in
                    folder.opened = state
                })
                try NewsData.shared.container.viewContext.save()
            } catch {
                throw DatabaseError.folderErrorMarkingExpanded
            }
        }
    }

    static func delete(id: Int32) async throws {
        let request: NSFetchRequest<CDFolder> = self.fetchRequest()
        let predicate = NSPredicate(format: "id == %d", id)
        request.predicate = predicate
        request.fetchLimit = 1
        do {
            let results  = try NewsData.shared.container.viewContext.fetch(request)
            if let folder = results.first {
                NewsData.shared.container.viewContext.delete(folder)
            }
            try NewsData.shared.container.viewContext.save()
        } catch {
            throw DatabaseError.folderErrorDeleting
        }
    }

    static func reset() {
        NewsData.shared.container.viewContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request )
            do {
                try NewsData.shared.container.viewContext.executeAndMergeChanges(using: deleteRequest)
            } catch {
                let updateError = error as NSError
                print("\(updateError), \(updateError.userInfo)")
            }
        }
    }

}
