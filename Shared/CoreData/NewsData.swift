//
//  NewsData.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import CoreData

class NewsData {

    static var mainThreadContext: NSManagedObjectContext = {
        let persistentContainer = NSPersistentContainer(name: "NewsData")
        persistentContainer.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        return persistentContainer.viewContext
    }()

}
