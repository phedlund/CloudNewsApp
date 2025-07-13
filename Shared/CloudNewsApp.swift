//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import BackgroundTasks
import SwiftData
import SwiftUI

@main
struct CloudNewsApp: App {
    private let container: ModelContainer
    private let newsModel: NewsModel
    private let modelActor: NewsDataModelActor
    private let syncManager: SyncManager

    @State private var isShowingAcknowledgements = false

#if !os(macOS)
    @Environment(\.scenePhase) var scenePhase
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif
    
    init() {
        container = SharedDatabase.shared.modelContainer
        self.modelActor = NewsDataModelActor(modelContainer: container)
        self.newsModel = NewsModel(databaseActor: modelActor)
        self.syncManager = SyncManager(databaseActor: modelActor)
        syncManager.configureSession()
    }
    
    var body: some Scene {
        #if os(macOS)
        Window(Text("CloudNews"), id: "mainWindow") {
            ContentView()
                .environment(newsModel)
                .environment(syncManager)
        }
        .modelContainer(container)
        .database(SharedDatabase.shared.database)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(newsModel: newsModel)
        }
        #else
        WindowGroup {
            ContentView()
                .environment(newsModel)
                .environment(syncManager)
                .sheet(isPresented: $isShowingAcknowledgements) {
                    NavigationView {
                        AcknowledgementsView()
                    }
                }
        }
        .modelContainer(container)
        .database(SharedDatabase.shared.database)
        .backgroundTask(.appRefresh(Constants.appRefreshTaskId)) {
            await scheduleAppRefresh()
            await syncManager.backgroundSync()
        }
        .backgroundTask(.urlSession(Constants.appUrlSessionId)) {
            syncManager.processSessionData()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                break
            case .inactive:
                break
            case .background:
                scheduleAppRefresh()
            @unknown default:
                fatalError("Unknown scene phase")
            }
        }
        .commands {
            PadCommands(newsModel: newsModel, isShowingAcknowledgements: $isShowingAcknowledgements)
        }
#endif
        
#if os(macOS)
        Settings {
            SettingsView()
                .environment(newsModel)
                .frame(width: 550, height: 500)
        }
        .restorationBehavior(.disabled)

        Window(Text("Log In"), id: "login") {
            LoginWebViewView()
                .frame(width: 600, height: 750)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)

        Window(Text("Feed Settings"), id: ModalSheet.feedSettings.rawValue) {
            FeedSettingsView()
                .environment(newsModel)
                .frame(width: 600, height: 500)
            
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .modelContainer(container)

        Window(Text("Add Feed"), id: ModalSheet.addFeed.rawValue) {
            AddView(selectedAdd: .feed)
                .environment(newsModel)
                .frame(width: 500, height: 220)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .modelContainer(container)

        Window(Text("Add Folder"), id: ModalSheet.addFolder.rawValue) {
            AddView(selectedAdd: .folder)
                .environment(newsModel)
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .modelContainer(container)

        Window(Text("Acknowledgement"), id: ModalSheet.acknowledgement.rawValue) {
            AcknowledgementsView()
                .frame(width: 600, height: 600)
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
#endif
    }

#if os(iOS)
    func scheduleAppRefresh() {
        let request = BGProcessingTaskRequest(identifier: Constants.appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: .fifteenMinutes)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submit called")
        } catch {
            print("Could not schedule app refresh task \(error.localizedDescription)")
        }
    }
#endif

}
