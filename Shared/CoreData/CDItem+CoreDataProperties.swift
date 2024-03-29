//
//  CDItem+CoreDataProperties.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/5/21.
//
//

import Foundation
import CoreData


extension CDItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDItem> {
        return NSFetchRequest<CDItem>(entityName: "CDItem")
    }

    @NSManaged public var author: String?
    @NSManaged public var body: String?
    @NSManaged public var displayBody: String
    @NSManaged public var displayTitle: String
    @NSManaged public var dateFeedAuthor: String
    @NSManaged public var enclosureLink: String?
    @NSManaged public var enclosureMime: String?
    @NSManaged public var feedId: Int32
    @NSManaged public var fingerprint: String?
    @NSManaged public var guid: String?
    @NSManaged public var guidHash: String?
    @NSManaged public var id: Int32
    @NSManaged public var lastModified: Int32
    @NSManaged public var mediaThumbnail: String?
    @NSManaged public var mediaDescription: String?
    @NSManaged public var pubDate: Int32
    @NSManaged public var rtl: Bool
    @NSManaged public var readable: String?
    @NSManaged public var starred: Bool
    @NSManaged public var title: String?
    @NSManaged public var unread: Bool
    @NSManaged public var url: String?

}

extension CDItem: Identifiable { }
