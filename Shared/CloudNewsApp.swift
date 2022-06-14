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

@main
struct CloudNewsApp: App {
    @StateObject var settings = Preferences()
#if !os(macOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    let sheetManager: PartialSheetManager = PartialSheetManager()
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let syncTimer = SyncTimer()
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
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands()
        }
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

struct AppCommands: Commands {
//    @ObservedObject var sessionManager: NoteSessionManager

    @CommandsBuilder var body: some Commands {
        SidebarCommands()
        CommandGroup(replacing: CommandGroupPlacement.newItem) {
            Button("New Feed...") {
                NotificationCenter.default.post(name: .newFeed, object: nil)
            }
            .keyboardShortcut("n")
            Button("New Folder...") {
                NotificationCenter.default.post(name: .newFolder, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandGroup(after: .sidebar) {
            Divider()
            Button("Refresh") {
                print("Refresh selected")
                Task {
                    try await NewsManager.shared.sync()
                }
            }
            .keyboardShortcut("r")
            Divider()
        }
        CommandMenu("Feed") {
            Divider()
            Button("Previous") {
                print("Favorite selected")
            }
            .keyboardShortcut("d", modifiers: [])
            Button("Next") {
                print("Category selected")
            }
            .keyboardShortcut("f", modifiers: [])
            Divider()
            Button("Delete") {
                print("Delete selected")
            }
            .keyboardShortcut(.delete)
        }
        CommandMenu("Article") {
            Button("Previous") {
                print("Favorite selected")
            }
            .keyboardShortcut("p", modifiers: [])
            Button("Next") {
                print("Category selected")
            }
            .keyboardShortcut("n", modifiers: [])
            Divider()
            Button("Mark") {
                print("Favorite selected")
            }
            .keyboardShortcut("u", modifiers: [])
            Button("Favorite") {
                print("Category selected")
            }
            .keyboardShortcut("s", modifiers: [])
            Divider()
            Button("Summary") {
                print("Favorite selected")
            }
            .keyboardShortcut("1")
            Button("Web") {
                print("Category selected")
            }
            .keyboardShortcut("2")
            Divider()
            Button("Mark Read") {
                print("Favorite selected")
            }
            .keyboardShortcut("a", modifiers: [])
        }
    }
}
