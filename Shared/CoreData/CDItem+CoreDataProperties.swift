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
    @NSManaged public var enclosureLink: String?
    @NSManaged public var enclosureMime: String?
    @NSManaged public var feedId: Int32
    @NSManaged public var fingerprint: String?
    @NSManaged public var guid: String?
    @NSManaged public var guidHash: String?
    @NSManaged public var id: Int32
    @NSManaged public var imageLink: String?
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

extension CDItem: Identifiable {

    @objc dynamic var displayTitle: String {
        if let title {
            return plainSummary(raw: title as String)
        } else {
            return "Untitled"
        }
    }

    @objc dynamic var displayBody: String {
        var displayBody = ""
        if let summaryBody = body {
            displayBody = summaryBody
        } else if let summaryBody = mediaDescription {
            displayBody = summaryBody
        }
        if !displayBody.isEmpty {
            if displayBody.range(of: "<style>", options: .caseInsensitive) != nil {
                if displayBody.range(of: "</style>", options: .caseInsensitive) != nil {
                    if let start = displayBody.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                       let end = displayBody.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                        let sub = displayBody[start..<end]
                        displayBody = displayBody.replacingOccurrences(of: sub, with: "")
                    }
                }
            }
            return  plainSummary(raw: displayBody)
        } else {
            return ""
        }
    }

    @objc dynamic var dateFeedAuthor: String {
        let clipLength = 50

        var dateLabelText = ""
        let date = Date(timeIntervalSince1970: TimeInterval(pubDate))
        dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: date))

        if !dateLabelText.isEmpty {
            dateLabelText.append(" | ")
        }

        if let itemAuthor = author, !itemAuthor.isEmpty {
            if itemAuthor.count > clipLength {
                dateLabelText.append(contentsOf: itemAuthor.filter( { !$0.isNewline }).prefix(clipLength))
                dateLabelText.append(String(0x2026))
            } else {
                dateLabelText.append(itemAuthor)
            }
        }

        let feedArray = value(forKey: "feedTitle") as? [CDFeed]

        if let feedTitle = feedArray?.first?.title {
            if let itemAuthor = author, !itemAuthor.isEmpty {
                if feedTitle != itemAuthor {
                    dateLabelText.append(" | \(feedTitle)")
                }
            } else {
                dateLabelText.append(feedTitle)
            }
        }

        return dateLabelText
    }

    @objc dynamic var imageUrl: URL? {
        if let imageLink, !imageLink.isEmpty, imageLink != "data:null", let url = URL(string: imageLink) {
            return url
        }
        return nil
    }

    override public class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        switch key {
        case "displayTitle":
            return keyPaths.union(Set(["title"]))
        case "displayBody":
            return keyPaths.union(Set(["body", "mediaDescription"]))
        case "dateFeedAuthor":
            return keyPaths.union(Set(["pubDate", "author", "feedTitle"]))
        case "imageUrl":
            return keyPaths.union(Set(["imageLink"]))
        default:
            return keyPaths
        }
    }
}
