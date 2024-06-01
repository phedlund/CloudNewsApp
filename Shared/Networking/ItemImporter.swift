//
//  ItemImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/21.
//

import SwiftData
import Foundation
import OSLog

class WebImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: WebImporter.self))
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @MainActor
    func updateFoldersInDatabase(urlRequest: URLRequest) async {
        do {
            let foldersData: FoldersDTO = try await fetchData(fromUrlRequest: urlRequest)
            for eachItem in foldersData.folders {
                let itemToStore = Folder(item: eachItem)
                modelContext.insert(itemToStore)
            }
        } catch {
            print("Error fetching data")
            print(error.localizedDescription)
        }
    }

    @MainActor
    func updateFeedsInDatabase(urlRequest: URLRequest) async {
        do {
            let feedsData: FeedsDTO = try await fetchData(fromUrlRequest: urlRequest)
            for eachItem in feedsData.feeds {
                let itemToStore = Feed(item: eachItem)
                modelContext.insert(itemToStore)
            }
        } catch {
            print("Error fetching data")
            print(error.localizedDescription)
        }
    }

    @MainActor
    func updateItemsInDatabase(urlRequest: URLRequest) async {
        do {
            let itemsData: ItemsDTO = try await fetchData(fromUrlRequest: urlRequest)
            for eachItem in itemsData.items {
                let itemToStore = Item(item: eachItem)
                modelContext.insert(itemToStore)
            }
        } catch {
            print("Error fetching data")
            print(error.localizedDescription)
        }
    }

    private func fetchData<T: Codable>(fromUrlRequest: URLRequest) async throws -> T {
        guard let downloadedData: T = await downloadData(fromUrlRequest: fromUrlRequest) else {
            return T.self as! T
        }

        return downloadedData
    }

    private func downloadData<T: Codable>(fromUrlRequest: URLRequest) async -> T? {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: fromUrlRequest, delegate: nil)
            guard let response = response as? HTTPURLResponse else {
                throw NetworkError.generic(message: "Bad response")
            }
            guard response.statusCode >= 200 && response.statusCode < 300 else {
                throw NetworkError.generic(message: "Bad status code")
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            guard let decodedResponse = try? decoder.decode(T.self, from: data) else {
                throw NetworkError.generic(message: "Unable to decode")
            }
            return decodedResponse
        } catch NetworkError.generic(let message) {
            print(message)
        } catch {
            print("An error occured downloading the data")
        }

        return nil
    }

}

class ItemImporter {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ItemImporter.self))
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
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

//                if let feedId = listItem["feedId"] as? Int64,
//                   let feed = modelContext.feed(id: feedId),
//                   let feedTitle = feed.title {
//                    if let itemAuthor = listItem["author"] as? String,
//                       !itemAuthor.isEmpty {
//                        if feedTitle != itemAuthor {
//                            dateLabelText.append(" | \(feedTitle)")
//                        }
//                    } else {
//                        dateLabelText.append(feedTitle)
//                    }
//                }
                currentItem["dateFeedAuthor"] = dateLabelText
                currentItems.append(currentItem)
            }

            let itemsData = try JSONSerialization.data(withJSONObject: currentItems)
//            let items = try JSONDecoder().decode([Item].self, from: itemsData)
//            for item in items {
//                DispatchQueue.main.async { [weak self] in
//                    guard let self else { return }
//                    modelContext.insert(item)
//                }
//            }
//            try modelContext.save()
            logger.debug("Finished importing item data.")
        } catch {
            self.logger.debug("Failed to execute items insert request.")
            throw DatabaseError.itemsFailedImport
        }
    }

}

class ItemPruner {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ItemPruner.self))
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func pruneItems(daysOld: Int) async throws {
        do {
            if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * daysOld), to: Date()) {
                try modelContext.delete(model: Item.self, where: #Predicate { $0.unread == false && $0.starred == false  && $0.lastModified < limitDate } )
            }
            //                try container.mainContext.save()
        } catch {
            self.logger.debug("Failed to execute items insert request.")
            throw DatabaseError.itemsFailedImport
        }
    }
}

