//
//  ItemImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/21.
//

import SwiftData
import Foundation
import OSLog

@MainActor
class FolderImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FolderImporter.self))

    func fetchFolders(_ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    do {
                        guard let foldersDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                              let folderDicts = foldersDict["folders"] as? [[String: Any]],
                              !folderDicts.isEmpty else {
                            return
                        }
                        logger.debug("Start importing folder data to the store...")
                        let foldersData = try JSONSerialization.data(withJSONObject: folderDicts)

                        let folders = try JSONDecoder().decode([Folder].self, from: foldersData)
                        if let container = NewsData.shared.container {
                            for folder in folders {
                                container.mainContext.insert(folder)
                            }
                            try container.mainContext.save()
                            //                        logger.debug("Start importing folder data to the store...")
                            //                        try await importFolders(from: folderDicts)
                            logger.debug("Finished importing folder data.")
                        }
                    } catch {
                        self.logger.debug("Failed to execute folders insert request.")
                        throw DatabaseError.foldersFailedImport
                    }
                default:
                    throw NetworkError.generic(message: "Error getting folders: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    private func importFolders(from propertiesList: [[String: Any]]) async throws {
        guard !propertiesList.isEmpty else { return }
        
        if let container = NewsData.shared.container {
            do {
                for f in propertiesList {
                    let folder = Folder(id: f["id"] as! Int64, opened: false, lastModified: 0, name: (f["name"] as! String), feeds: [Feed]())
                    container.mainContext.insert(folder)
                }
//                let success = try container.mainContext.insert(propertiesList, model: Folder.self)
//                if success {
                    try container.mainContext.save()
//                }
            } catch {
                self.logger.debug("Failed to execute folders insert request.")
            throw DatabaseError.foldersFailedImport
        }
            
    }
    }

}

@MainActor
class FeedImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FeedImporter.self))

    func fetchFeeds(_ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let feedsDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let feedDicts = feedsDict["feeds"] as? [[String: Any]],
                          !feedDicts.isEmpty else {
                        return
                    }

                    logger.debug("Start importing feed data to the store...")
//                    try await importFeeds(from: feedDicts)
                    let feedsData = try JSONSerialization.data(withJSONObject: feedDicts)

                    let feeds = try JSONDecoder().decode([Feed].self, from: feedsData)
                    if let container = NewsData.shared.container {
                        for feed in feeds {
                            container.mainContext.insert(feed)
                        }
                        try container.mainContext.save()
                        //                        logger.debug("Start importing folder data to the store...")
                        //                        try await importFolders(from: folderDicts)
                        logger.debug("Finished importing folder data.")
                    }

                    logger.debug("Finished importing feed data.")
                default:
                    throw NetworkError.generic(message: "Error getting feeds: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    private func importFeeds(from propertiesList: [[String: Any]]) async throws {
        guard !propertiesList.isEmpty else { return }
        
//        if let container = NewsData.shared.container {
//            do {
//                let success = try container.mainContext.insert(propertiesList, model: Feed.self)
//                if success {
//                    try await container.mainContext.save()
//            }
//            } catch {
//                self.logger.debug("Failed to execute feeds insert request.")
//            throw DatabaseError.feedsFailedImport
//        }
            
//    }
    }

}

@MainActor
class ItemImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ItemImporter.self))

    func fetchItems(_ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    guard let itemsDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let itemDicts = itemsDict["items"] as? [[String: Any]],
                          !itemDicts.isEmpty else {
                        return
                    }
                    logger.debug("Start importing item data to the store...")
                    try await importItems(from: itemDicts)
                    logger.debug("Finished importing item data.")
                default:
                    throw NetworkError.generic(message: "Error getting items: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch(let error) {
            throw NetworkError.generic(message: error.localizedDescription)
        }
    }

    private func importItems(from propertiesList: [[String: Any]]) async throws {
        guard !propertiesList.isEmpty else { return }

        if let container = NewsData.shared.container {
            do {
                var currentItems = [[String: Any]]()
                for listItem in propertiesList {
                    var currentItem = listItem
                    //                    currentItem.addEntries(from: listItem)
                    var displayTitle = "Untitled"
                    if let title = listItem["title"] as? String {
                        displayTitle = plainSummary(raw: title)
                    }
                    currentItem["displayTitle"] = displayTitle

                    var summary = ""
                    if let body = listItem["body"] as? String {
                        summary = body
                    } else if let mediaDescription = listItem["mediaDescription"] as? String {
                        summary = mediaDescription
                    }
                    if !summary.isEmpty {
                        if summary.range(of: "<style>", options: .caseInsensitive) != nil {
                            if summary.range(of: "</style>", options: .caseInsensitive) != nil {
                                if let start = summary.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                                   let end = summary.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                                    let sub = summary[start..<end]
                                    summary = summary.replacingOccurrences(of: sub, with: "")
                                }
                            }
                        }
                    }
                    currentItem["displayBody"] = plainSummary(raw: summary)

                    let clipLength = 50
                    var dateLabelText = ""
                    if let pubDate = listItem["pubDate"] as? Double {
                        let date = Date(timeIntervalSince1970: TimeInterval(pubDate))
                        dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: date))

                        if !dateLabelText.isEmpty {
                            dateLabelText.append(" | ")
                        }
                    }
                    if let itemAuthor = listItem["author"] as? String,
                       !itemAuthor.isEmpty {
                        if itemAuthor.count > clipLength {
                            dateLabelText.append(contentsOf: itemAuthor.filter( { !$0.isNewline }).prefix(clipLength))
                            dateLabelText.append(String(0x2026))
                        } else {
                            dateLabelText.append(itemAuthor)
                        }
                    }

                    if let feedId = listItem["feedId"] as? Int64,
                       let feed = Feed.feed(id: feedId),
                       let feedTitle = feed.title {
                        if let itemAuthor = listItem["author"] as? String,
                           !itemAuthor.isEmpty {
                            if feedTitle != itemAuthor {
                                dateLabelText.append(" | \(feedTitle)")
                            }
                        } else {
                            dateLabelText.append(feedTitle)
                        }
                    }
                    currentItem["dateFeedAuthor"] = dateLabelText
                    currentItems.append(currentItem)
                }
                //                let success = try container.mainContext.insert(currentItems, model: Item.self)
                //                if success {
                //                    try await container.mainContext.save()
                //                }

                let itemsData = try JSONSerialization.data(withJSONObject: currentItems)
                let items = try JSONDecoder().decode([Item].self, from: itemsData)
                for item in items {
                    container.mainContext.insert(item)
                }
                try container.mainContext.save()
                //                        logger.debug("Start importing folder data to the store...")
                //                        try await importFolders(from: folderDicts)
                logger.debug("Finished importing item data.")
            } catch {
                self.logger.debug("Failed to execute items insert request.")
                throw DatabaseError.itemsFailedImport
            }
        }

    }

}

@MainActor
class ItemPruner {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ItemPruner.self))

    func pruneItems(daysOld: Int) async throws {
        if let container = NewsData.shared.container {
            do {
                let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * daysOld), to: Date())
                let limitDateEpoch: Int64  = Int64(limitDate?.timeIntervalSince1970 ?? 1)
                try container.mainContext.delete(model: Item.self, where: #Predicate { $0.unread == false && $0.starred == false  && $0.lastModified < limitDateEpoch } )
            } catch {
                self.logger.debug("Failed to execute items insert request.")
                throw DatabaseError.itemsFailedImport
            }
        }
    }
}

