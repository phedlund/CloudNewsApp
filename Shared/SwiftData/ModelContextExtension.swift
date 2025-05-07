//
//  ModelContextExtension.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/8/24.
//

import Foundation
import SwiftData

extension ModelContext {

    func feed(id: Int64) -> Feed? {
        let predicate = #Predicate<Feed>{ $0.id == id }

        var descriptor = FetchDescriptor<Feed>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let results  = try fetch(descriptor)
            return results.first
        } catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        return nil
    }
    
}
