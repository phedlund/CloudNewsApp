//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import BackgroundTasks
import SwiftData
import SwiftUI
import Valet

@main
struct CloudNewsApp: App {
    private let container: ModelContainer
    private let newsModel: NewsModel
    private let modelActor: NewsModelActor
    private let syncManager: SyncManager
    let logger = LogManager.shared.logger

    @State private var isShowingAddFolder = false
    @State private var isShowingAddFeed = false
    @State private var isShowingFeedSettings = false
    @State private var isShowingAcknowledgements = false

#if !os(macOS)
    @Environment(\.scenePhase) var scenePhase
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif

    init() {
        do {
            container = try ModelContainer(for: schema)
            self.modelActor = NewsModelActor(modelContainer: container)
            self.newsModel = NewsModel(modelContainer: container)
            self.syncManager = SyncManager(modelContainer: container)
            ContentBlocker.shared.rules(completion: { _ in })
            let _ = CssProvider.shared.css()
            migrateKeychain()
            logger.info("App launched")
        } catch {
            fatalError("Failed to create container")
        }
    }

    var body: some Scene {
#if os(macOS)
        Window(Text("CloudNews"), id: "mainWindow") {
            ContentView()
                .environment(newsModel)
                .environment(syncManager)
        }
        .modelContainer(container)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(newsModel: newsModel,
                        isShowingAddFeed: $isShowingAddFeed,
                        isShowingFeedSettings: $isShowingFeedSettings,
                        isShowingAddFolder: $isShowingAddFolder,
                        isShowingAcknowledgements: $isShowingAcknowledgements)
        }
#else
        WindowGroup {
            ContentView()
                .environment(newsModel)
                .environment(syncManager)
                .task {
                    // Run all pending migrations once when the app starts
                    let context = ModelContext(container)
                    try? await DataMigrationManager.runPendingMigrations(modelContext: context)
                }
                .sheet(isPresented: $isShowingAcknowledgements) {
                    NavigationView {
                        AcknowledgementsView()
                    }
                }
                .sheet(isPresented: $isShowingAddFolder) {
                    NavigationView {
                        AddView(selectedAdd: .folder)
                            .environment(newsModel)
                    }
                    .modelContainer(container)
                }
                .sheet(isPresented: $isShowingAddFeed) {
                    NavigationView {
                        AddView(selectedAdd: .feed)
                            .environment(newsModel)
                    }
                    .modelContainer(container)
                }
                .sheet(isPresented: $isShowingFeedSettings) {
                    NavigationView {
                        FeedSettingsView()
                            .environment(newsModel)
                    }
                    .modelContainer(container)
                }
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(Constants.appRefreshTaskId)) {
            logger.info("Scheduling app refresh")
            await scheduleAppRefresh()
            logger.info("Starting background sync")
            try? await syncManager.backgroundSync()
        }
        .backgroundTask(.urlSession(Constants.appUrlSessionId)) {
            logger.info("Starting background processing")
            await syncManager.processSessionData()
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
            AppCommands(newsModel: newsModel,
                        isShowingAddFeed: $isShowingAddFeed,
                        isShowingFeedSettings: $isShowingFeedSettings,
                        isShowingAddFolder: $isShowingAddFolder,
                        isShowingAcknowledgements: $isShowingAcknowledgements)
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
            LoginView()
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

        Window(Text("Acknowledgements"), id: ModalSheet.acknowledgement.rawValue) {
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
            logger.info("Added background task to refresh app")
        } catch {
            logger.error("Could not schedule app refresh task \(error.localizedDescription)")
        }
    }
#endif

    private func migrateKeychain() {
        let valet = Valet.valet(with: Identifier(nonEmpty: "CloudNews")!, accessibility: .afterFirstUnlock)
        let query: [String: AnyHashable] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.peterandlinda.iOCNews"
        ]

        do {
            try valet.migrateObjects(matching: query, removeOnCompletion: true)
        } catch {
            print("Error migrating keychain data: \(error)")
        }
    }

}
