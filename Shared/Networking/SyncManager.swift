//
//  DataManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/26/24.
//


import SwiftUI
import Combine

@Observable
final class SyncManager: @unchecked Sendable {
    var foldersData = Data()
    var feedsData = Data()
    var itemsData = Data()

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
        if let backgroundSession {
            let newestKnownLastModified = await modelActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)

            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try? updatedItemRouter.urlRequest()

            let response = await withTaskCancellationHandler {
                try? await URLSession.shared.data (for: itemsRequest!)
            } onCancel: {
                let task = backgroundSession.downloadTask(with: itemsRequest!)
                task.taskDescription = "items"
                task.resume ()
            }

            if let data = response {
                itemsData = data.0
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
                            itemsData = data
                        }
                    }
                }
            }
        }
    }

    func sync() async {
        do {
            let foldersRequest = try Router.folders.urlRequest()
            let feedsRequest = try Router.feeds.urlRequest()

            let newestKnownLastModified = await modelActor.maxLastModified()
            Preferences().lastModified = Int32(newestKnownLastModified)
            let updatedParameters: ParameterDict = ["type": 3,
                                                    "lastModified": newestKnownLastModified,
                                                    "id": 0]
            let updatedItemRouter = Router.updatedItems(parameters: updatedParameters)

            let itemsRequest = try updatedItemRouter.urlRequest()

            foldersData = try await URLSession.shared.data (for: foldersRequest).0
            feedsData = try await URLSession.shared.data (for: feedsRequest).0
            itemsData = try await URLSession.shared.data (for: itemsRequest).0
        } catch {

        }
    }
}
