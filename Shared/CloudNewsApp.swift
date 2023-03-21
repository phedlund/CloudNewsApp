//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import BackgroundTasks
import SwiftUI

@main
struct CloudNewsApp: App {
    @StateObject private var feedModel = FeedModel()

#if !os(macOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif

    private let appRefreshTaskId = "dev.pbh.cloudnews.sync"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, NewsData.shared.container.viewContext)
                .environmentObject(feedModel)
        }
#if os(macOS)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(model: feedModel)
        }
#else
        .onChange(of: scenePhase) { newPhase in
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
        .backgroundTask(.appRefresh(appRefreshTaskId)) {
            do {
                try await NewsManager().sync()
                await scheduleAppRefresh()
            } catch { }
        }
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
                FeedSettingsView(Int(value))
                    .frame(width: 600, height: 500)
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
        let request = BGAppRefreshTaskRequest(identifier: appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: .fiveMinutes)
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Submit called")
        } catch {
            print("Could not schedule app refresh task \(error.localizedDescription)")
        }
    }
#endif
}
