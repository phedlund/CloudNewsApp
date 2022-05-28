//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

#if os(iOS)
import PartialSheet
#endif
import SwiftUI

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
#endif

@main
struct CloudNewsApp: App {
    @StateObject var settings = Preferences()
#if !os(macOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    let sheetManager: PartialSheetManager = PartialSheetManager()
#else
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
#if os(iOS)
                .environmentObject(sheetManager)
#endif
        }
#if os(macOS)
        .windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
#endif

#if os(macOS)
        Settings {
            ScrollView {
                SettingsView()
                    .padding(20)
            }
            .frame(width: 500, height: 600)
        }

        WindowGroup("Login") {
            LoginWebViewView()
                .navigationTitle("Login Information")
                .frame(minWidth: 350, idealWidth: 600, maxWidth: 800, minHeight: 500, idealHeight: 750, maxHeight: 900)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "login"))
#endif
    }
}
