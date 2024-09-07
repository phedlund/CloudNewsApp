//
//  DataManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/26/24.
//


import Foundation
import SwiftData

@Observable
final class SyncManager: @unchecked Sendable {
    private let modelActor: BackgroundModelActor
    private var backgroundSession: URLSession?

    init(modelActor: BackgroundModelActor) {
        self.modelActor = modelActor
    }

    func configureSession() {
        let backgroundSessionConfig = URLSessionConfiguration.background(withIdentifier: Constants.appUrlSessionId)
        backgroundSessionConfig.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: backgroundSessionConfig)
    }

    func backgroundSync() async {
        try? await pruneItems()
        if let backgroundSession {
            let foldersRequest = try? Router.folders.urlRequest()
            let foldersResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: foldersRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: foldersRequest!)
                task.taskDescription = "folders"
                task.resume ()
            }

            if let data = foldersResponse {
                parseFolders(data: data.0)
            }

            let feedsRequest = try? Router.feeds.urlRequest()

            let feedsResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: feedsRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: feedsRequest!)
                task.taskDescription = "feeds"
                task.resume ()
            }

            if let data = feedsResponse {
                parseFeeds(data: data.0)
            }


            let newestKnownLastModified = await modelActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try? updatedItemRouter.urlRequest()

            let itemsResponse = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: itemsRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: itemsRequest!)
                task.taskDescription = "items"
                task.resume ()
            }

            if let data = itemsResponse {
                parseItems(data: data.0)
            }
        }
    }

    func processSessionData() {
        backgroundSession?.getAllTasks { [self] tasks in
            for task in tasks {
                if task.state == .suspended || task.state == .canceling { continue }
                // NOTE: It seems the task state is .running when this is called, instead of .completed as one might expect.

                if let dlTask = task as? URLSessionDownloadTask {
                    if let url = dlTask.response?.url {
                        if let data = try? Data(contentsOf: url) {
                            switch dlTask.taskDescription {
                            case "folders":
                                parseFolders(data: data)
                            case "feeds":
                                parseFeeds(data: data)
                            case "items":
                                parseItems(data: data)
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    func sync() async {
        do {
            let fetchDescriptor = FetchDescriptor<Item>(predicate: nil )
            let itemCount = try await modelActor.itemCount()
            if itemCount == 0 {
                await initialSync()
            } else {
                await repeatSync()
            }
        } catch { }
    }

    func initialSync() async {

    }

    func repeatSync() async {
        do {
            try await pruneItems()

            let foldersRequest = try Router.folders.urlRequest()
            let feedsRequest = try Router.feeds.urlRequest()

            let newestKnownLastModified = await modelActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)
            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try updatedItemRouter.urlRequest()

            let foldersData = try await URLSession.shared.data (for: foldersRequest).0
            let feedsData = try await URLSession.shared.data (for: feedsRequest).0
            let itemsData = try await URLSession.shared.data (for: itemsRequest).0
            parseFolders(data: foldersData)
            parseFeeds(data: feedsData)
            parseItems(data: itemsData)
        } catch {

        }
    }

    func parseFolders(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FoldersDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        Task {
            for eachItem in decodedResponse.folders {
                let itemToStore = Folder(item: eachItem)
                await modelActor.insert(itemToStore)
            }
            try? await modelActor.save()
        }
    }

    func parseFeeds(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(FeedsDTO.self, from: data) else {
            //                    throw NetworkError.generic(message: "Unable to decode")
            return
        }
        Task {
            for eachItem in decodedResponse.feeds {
                let itemToStore = Feed(item: eachItem)
                await modelActor.insert(itemToStore)
            }
            try? await modelActor.save()
        }
    }

    func parseItems(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let decodedResponse = try? decoder.decode(ItemsDTO.self, from: data) else {
            return
        }
        Task {
            for eachItem in decodedResponse.items {
                let itemToStore = await Item(item: eachItem)
                await modelActor.insert(itemToStore)
            }
            try? await modelActor.save()
        }
    }

    func pruneItems() async throws {
        do {
            if let limitDate = Calendar.current.date(byAdding: .day, value: (-30 * Preferences().keepDuration), to: Date()) {
                print("limitDate: \(limitDate) date: \(Date())")
                try await modelActor.delete(Item.self, where: #Predicate { $0.unread == false && $0.starred == false && $0.lastModified < limitDate } )
            }
        } catch {
            throw DatabaseError.itemsFailedImport
        }
    }

}
