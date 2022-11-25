//
//  ItemImporter.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/21.
//

import CoreData
import Foundation

class FolderImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
      importContext = persistentContainer.newBackgroundContext()
      importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let foldersDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let folderDicts = foldersDict["folders"] as? [[String: Any]],
                          !folderDicts.isEmpty else {
                        return
                    }
                    let request = NSBatchInsertRequest(entityName: CDFolder.entityName, objects: folderDicts)
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Folders imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting folders")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}

class FeedImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
        importContext = persistentContainer.newBackgroundContext()
        importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
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
                    let request = NSBatchInsertRequest(entityName: CDFeed.entityName, objects: feedDicts)
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Feeds imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting feeds")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}

class ItemImporter {
    let importContext: NSManagedObjectContext

    init(persistentContainer: NSPersistentContainer) {
        importContext = persistentContainer.newBackgroundContext()
        importContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    func download( _ urlRequest: URLRequest) async throws {
        do {
            let (data, response) = try await ServerStatus.shared.session.data(for: urlRequest, delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
//                print(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
//                print(String(data: data, encoding: .utf8) ?? "")
                switch httpResponse.statusCode {
                case 200:
                    guard let itemsDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          var itemDicts = itemsDict["items"] as? [[String: Any]],
                          !itemDicts.isEmpty else {
                        return
                    }
                    let request = NSBatchInsertRequest(entity: CDItem.entity(), dictionaryHandler: { dict in
                        let currentItem = itemDicts.removeFirst()
                        dict.addEntries(from: currentItem)

                        if let title = currentItem["title"] as? String {
                            dict["displayTitle"] = plainSummary(raw: title)
                        }

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
                            dict["displayBody"] = plainSummary(raw: summary)
                        }

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

                        return itemDicts.isEmpty
                    })
                    request.resultType = NSBatchInsertRequestResultType.count
                    let result = try importContext.execute(request) as? NSBatchInsertResult
                    print("Items imported \(result?.result ?? -1)")
                    try importContext.save()
                default:
                    throw PBHError.networkError(message: "Error getting items")
                }
            }
        } catch(let error) {
            throw error
        }
    }
}
