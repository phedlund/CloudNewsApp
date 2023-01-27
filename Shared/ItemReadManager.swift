//
//  ItemReadManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 1/20/23.
//

import CoreData
import Foundation

class ItemReadManager {

    static let shared = ItemReadManager()

    private let readContext: NSManagedObjectContext
    private let session = ServerStatus.shared.session

    init() {
        readContext = NewsData.shared.newTaskContext()
        readContext.name = "readContext"
        readContext.transactionAuthor = "readContext"
    }

    func markRead(items: [CDItem], unread: Bool) async throws {
        guard !items.isEmpty else {
            return
        }
        do {
            let itemIds = items.map( { $0.id } )
            try await readContext.perform {
                let batchUpdateRequest = self.newBatchUpdateRequest(with: itemIds, unread: unread)
                if let result = try self.readContext.execute(batchUpdateRequest) as? NSBatchUpdateResult,
                   let objectIDArray = result.result as? [NSManagedObjectID] {
                    let changes = [NSUpdatedObjectsKey: objectIDArray]
                    DispatchQueue.main.async {
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [NewsData.shared.container.viewContext])
                    }
                }
            }

            let parameters: ParameterDict = ["items": itemIds]
            var router: Router
            if unread {
                router = Router.itemsUnread(parameters: parameters)
            } else {
                router = Router.itemsRead(parameters: parameters)
            }
            let (_, response) = try await session.data(for: router.urlRequest(), delegate: nil)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    if unread {
                        try await readContext.perform {
                            let batchDeleteRequest = self.newBatchDeleteRequest(with: itemIds, entity: CDUnread.entity())
                            if let result = try self.readContext.execute(batchDeleteRequest) as? NSBatchDeleteResult {
                                print(result)
                            }
                        }
                    } else {
                        try await readContext.perform {
                            let batchDeleteRequest = self.newBatchDeleteRequest(with: itemIds, entity: CDRead.entity())
                            if let result = try self.readContext.execute(batchDeleteRequest) as? NSBatchDeleteResult {
                                print(result)
                            }
                        }
                    }
                default:
                    if unread {
                        try await readContext.perform {
                            let batchInsertRequest = self.newBatchInsertRequest(with: itemIds, entity: CDRead.entity())
                            if let result = try self.readContext.execute(batchInsertRequest) as? NSBatchDeleteResult {
                                print(result)
                            }
                        }
                    } else {
                        try await readContext.perform {
                            let batchInsertRequest = self.newBatchInsertRequest(with: itemIds, entity: CDUnread.entity())
                            if let result = try self.readContext.execute(batchInsertRequest) as? NSBatchDeleteResult {
                                print(result)
                            }
                        }
                    }
                }
            }
        } catch(let error) {
            throw PBHError.networkError(message: error.localizedDescription)
        }
    }

    private func newBatchUpdateRequest(with itemIds: [Int32], unread: Bool) -> NSBatchUpdateRequest {
        let batchUpdateRequest = NSBatchUpdateRequest(entity: CDItem.entity())
        batchUpdateRequest.predicate = NSPredicate(format:"id IN %@", itemIds)
        batchUpdateRequest.propertiesToUpdate = ["unread": NSNumber(booleanLiteral: unread)]
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        return batchUpdateRequest
    }

    private func newBatchDeleteRequest(with itemIds: [Int32], entity: NSEntityDescription) -> NSBatchDeleteRequest {
        let request = NSFetchRequest<NSFetchRequestResult>()
        request.entity = entity
        let predicate = NSPredicate(format: "itemId IN %@", itemIds)
        request.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        deleteRequest.resultType = .resultTypeCount
        return deleteRequest
    }

    private func newBatchInsertRequest(with itemIds: [Int32], entity: NSEntityDescription) -> NSBatchInsertRequest {
        var index = 0
        let total = itemIds.count
        let propertyList = itemIds.map( { ["itemId": $0] })
        let batchInsertRequest = NSBatchInsertRequest(entity: entity, dictionaryHandler: { dict in
            guard index < total else { return true }
            let currentItem = propertyList[index]
            dict.addEntries(from: currentItem)
            index += 1
            return false
        })
        return batchInsertRequest
    }

}
