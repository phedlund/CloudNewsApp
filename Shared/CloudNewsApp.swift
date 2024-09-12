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
    private let feedModel: FeedModel
    private let newsData = NewsData()
    private let modelActor: BackgroundModelActor
    private let syncManager: SyncManager

#if !os(macOS)
    @Environment(\.scenePhase) var scenePhase
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif
    
    init() {
        container = newsData.container!
        self.modelActor = BackgroundModelActor(modelContainer: container)
        self.feedModel = FeedModel(backgroundModelActor: modelActor)
        self.syncManager = SyncManager(modelActor: modelActor)
        syncManager.configureSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(feedModel)
                .environment(syncManager)
        }
        .modelContainer(container)
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
#if os(macOS)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(model: feedModel)
        }
#else
        //        .backgroundTask(.urlSession(appRefreshTaskId)) {
        //            dataImporter.sync()
        //            await scheduleAppRefresh()
        //        }
#endif
        
#if os(macOS)
        Settings {
            SettingsView()
        }
        
        WindowGroup(Text("Log In"), id: "login") {
            LoginWebViewView()
                .frame(width: 600, height: 750)
        }
        .windowResizability(.contentSize)
        
        WindowGroup(Text("Feed Settings"), id: ModalSheet.feedSettings.rawValue, for: Int32.self) { feedId in
            if let value = feedId.wrappedValue {
                //                FeedSettingsView(Int(value))
                //                    .frame(width: 600, height: 500)
            }
        }
        .windowResizability(.contentSize)
        
        WindowGroup(Text("Add Feed"), id: ModalSheet.addFeed.rawValue) {
            AddView(.feed)
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)
        
        WindowGroup(Text("Add Folder"), id: ModalSheet.addFolder.rawValue) {
            AddView(.folder)
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)
        
        WindowGroup(Text("Acknowledgement"), id: ModalSheet.acknowledgement.rawValue) {
            AcknowledgementsView()
                .frame(width: 600, height: 600)
        }
        .windowResizability(.contentSize)
        
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
