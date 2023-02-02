//
//  ItemImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/21.
//

import CoreData
import Foundation
import OSLog

class FolderImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: FolderImporter.self))

    func fetchFolders(_ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    guard let foldersDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let folderDicts = foldersDict["folders"] as? [[String: Any]],
                          !folderDicts.isEmpty else {
                        return
                    }

                    logger.debug("Start importing folder data to the store...")
                    try await importFolders(from: folderDicts)
                    logger.debug("Finished importing folder data.")
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

        let taskContext = NewsData.shared.newTaskContext()
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importFolders"

        try await taskContext.perform {
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
            throw DatabaseError.foldersFailedImport
        }

        logger.debug("Successfully inserted folder data.")
    }

    private func newBatchInsertRequest(with propertyList: [[String: Any]]) -> NSBatchInsertRequest {
        var index = 0
        let total = propertyList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: CDFolder.entity(), dictionaryHandler: { dict in
            guard index < total else { return true }
            let currentFolder = propertyList[index]
            dict.addEntries(from: currentFolder)
            index += 1
            return false
        })
        return batchInsertRequest
    }

}

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

                    logger.debug("Start importing folder data to the store...")
                    try await importFeeds(from: feedDicts)
                    logger.debug("Finished importing folder data.")
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

        let taskContext = NewsData.shared.newTaskContext()
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importFeeds"

        try await taskContext.perform {
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
            throw DatabaseError.feedsFailedImport
        }

        logger.debug("Successfully inserted feed data.")
    }

    private func newBatchInsertRequest(with propertyList: [[String: Any]]) -> NSBatchInsertRequest {
        var index = 0
        let total = propertyList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: CDFeed.entity(), dictionaryHandler: { dict in
            guard index < total else { return true }
            let currentFolder = propertyList[index]
            dict.addEntries(from: currentFolder)
            index += 1
            return false
        })
        return batchInsertRequest
    }

}

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
                    logger.debug("Start importing data to the store...")
                    try await importItems(from: itemDicts)
                    logger.debug("Finished importing data.")
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

        let taskContext = NewsData.shared.newTaskContext()
        taskContext.name = "importContext"
        taskContext.transactionAuthor = "importItems"

        try await taskContext.perform {
            let batchInsertRequest = self.newBatchInsertRequest(with: propertiesList)
            if let fetchResult = try? taskContext.execute(batchInsertRequest),
               let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool, success {
                return
            }
            self.logger.debug("Failed to execute batch insert request.")
            throw DatabaseError.itemsFailedImport
        }

        logger.debug("Successfully inserted item data.")
    }

    private func newBatchInsertRequest(with propertyList: [[String: Any]]) -> NSBatchInsertRequest {
        var index = 0
        let total = propertyList.count

        // Provide one dictionary at a time when the closure is called.
        let batchInsertRequest = NSBatchInsertRequest(entity: CDItem.entity(), dictionaryHandler: { dict in
            guard index < total else { return true }
            let currentItem = propertyList[index]
            dict.addEntries(from: currentItem)

            var displayTitle = "Untitled"
            if let title = currentItem["title"] as? String {
                displayTitle = plainSummary(raw: title)
            }
            dict["displayTitle"] = displayTitle

            var summary = ""
            if let body = currentItem["body"] as? String {
                summary = body
            } else if let mediaDescription = currentItem["mediaDescription"] as? String {
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
            dict["displayBody"] = plainSummary(raw: summary)

            let clipLength = 50
            var dateLabelText = ""
            if let pubDate = currentItem["pubDate"] as? Double {
                let date = Date(timeIntervalSince1970: TimeInterval(pubDate))
                dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: date))

                if !dateLabelText.isEmpty {
                    dateLabelText.append(" | ")
                }
            }
            if let itemAuthor = currentItem["author"] as? String,
               !itemAuthor.isEmpty {
                if itemAuthor.count > clipLength {
                    dateLabelText.append(contentsOf: itemAuthor.filter( { !$0.isNewline }).prefix(clipLength))
                    dateLabelText.append(String(0x2026))
                } else {
                    dateLabelText.append(itemAuthor)
                }
            }

            if let feedId = currentItem["feedId"] as? Int32,
               let feed = CDFeed.feed(id: feedId),
                let feedTitle = feed.title {
                if let itemAuthor = currentItem["author"] as? String,
                   !itemAuthor.isEmpty {
                    if feedTitle != itemAuthor {
                        dateLabelText.append(" | \(feedTitle)")
                    }
                } else {
                    dateLabelText.append(feedTitle)
                }
            }
            dict["dateFeedAuthor"] = dateLabelText

            index += 1
            return false
        })
        return batchInsertRequest
    }

}

class ItemPruner {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ItemPruner.self))

    func pruneItems(daysOld: Int) async throws {
        let taskContext = NewsData.shared.newTaskContext()
        taskContext.name = "deleteContext"
        taskContext.transactionAuthor = "pruneItems"

        try await taskContext.perform {
            let batchDeleteRequest = self.newBatchDeleteRequest(daysOld: daysOld)
            if let fetchResult = try? taskContext.execute(batchDeleteRequest),
               let batchDeleteResult = fetchResult as? NSBatchDeleteResult,
               let success = batchDeleteResult.result as? Bool, success {
                return
            }
            self.logger.debug("Failed to execute batch delete request.")
            throw DatabaseError.failedDeletion
        }

        logger.debug("Successfully deleted item data.")
    }

    private func newBatchDeleteRequest(daysOld: Int) -> NSBatchDeleteRequest {
        if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * daysOld), to: Date())?.timeIntervalSince1970 {
            let predicate1 = NSPredicate(format: "unread == false")
            let predicate2 = NSPredicate(format: "starred == false")
            let predicate3 = NSPredicate(format:"lastModified < %d", Int32(limitDate))
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1, predicate2, predicate3])

            let request = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: CDItem.self))
            request.predicate = predicate
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            return batchDeleteRequest
        }
        return NSBatchDeleteRequest(objectIDs: [])
    }
}
