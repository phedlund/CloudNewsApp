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
            try? modelContext.save()
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
            try? modelContext.save()
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
            try? modelContext.save()
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
        } catch {
            self.logger.debug("Failed to execute item pruning.")
            throw DatabaseError.itemsFailedImport
        }
    }
}

