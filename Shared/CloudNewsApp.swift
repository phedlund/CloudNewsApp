//
//  CloudNewsApp.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import SwiftUI

@main
struct CloudNewsApp: App {
    @StateObject private var settings = Preferences()
    @StateObject private var nodeTree = FeedModel()

#if !os(macOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let syncTimer = SyncTimer()
#endif

    var body: some Scene {
        WindowGroup {
            ContentView(model: nodeTree, settings: settings)
        }
#if os(macOS)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(model: nodeTree)
        }
#endif

#if os(macOS)
        Settings {
            SettingsView()
        }

        Window(Text("Log In"), id: "login") {
            LoginWebViewView()
                .frame(width: 600, height: 750)
        }
        .windowResizability(.contentSize)

        WindowGroup(Text("Feed Settings"), id: ModalSheet.feedSettings.rawValue, for: Int32.self) { feedId in
            FeedSettingsView(Int(feedId.wrappedValue!))
                .frame(width: 600, height: 500)
        }
        .windowResizability(.contentSize)

        WindowGroup(Text("Rename Folder"), id: ModalSheet.folderRename.rawValue, for: Int32.self) { folderId in
            FolderRenameView(Int(folderId.wrappedValue!))
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)

        Window(Text("Add Feed"), id: ModalSheet.addFeed.rawValue) {
            AddView(.feed)
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)

        Window(Text("Add Folder"), id: ModalSheet.addFolder.rawValue) {
            AddView(.folder)
                .frame(width: 500, height: 200)
        }
        .windowResizability(.contentSize)

#endif
    }
}

#if os(macOS)
struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow
    @ObservedObject var model: FeedModel

    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0

    @CommandsBuilder var body: some Commands {
        SidebarCommands()
        CommandGroup(replacing: CommandGroupPlacement.newItem) {
            EmptyView()
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
        CommandMenu("Folder") {
            Button("Rename...") {
                switch model.currentNode.nodeType {
                case .empty, .all, .starred, .feed(id: _):
                    break
                case .folder(id: let id):
                    openWindow(id: ModalSheet.folderRename.rawValue, value: id)
                }
            }
            .disabled(isFolderRenameDisabled())
            Divider()
            Button("New Folder...") {
                openWindow(id: ModalSheet.addFolder.rawValue)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Delete Folder") {
                print("Delete selected")
            }
            .keyboardShortcut(.delete)
            .disabled(isFolderRenameDisabled())
        }
        CommandMenu("Feed") {
            Button("Previous") {
                print("Favorite selected")
            }
            .keyboardShortcut("d", modifiers: [])
            Button("Next") {
                print("Category selected")
            }
            .keyboardShortcut("f", modifiers: [])
            Divider()
            Button("Settings...") {
                switch model.currentNode.nodeType {
                case .empty, .all, .starred, .folder(id: _):
                    break
                case .feed(id: let id):
                    openWindow(id: ModalSheet.feedSettings.rawValue, value: id)
                }
            }
            .disabled(isFeedSettingsDisabled())
            Divider()
            Button("New Feed...") {
                openWindow(id: ModalSheet.addFeed.rawValue)
            }
            .keyboardShortcut("n")
            Button("Delete Feed") {
                print("Delete selected")
            }
            .keyboardShortcut(.delete)
            .disabled(isFeedSettingsDisabled())
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
            MarkReadButton(node: model.currentNode)
        }
    }

    private func isFolderRenameDisabled() -> Bool {
        switch model.currentNode.nodeType {
        case .empty, .all, .starred, .feed(id: _):
            return true
        case .folder(id: _):
            return false
        }
    }

    private func isFeedSettingsDisabled() -> Bool {
        switch model.currentNode.nodeType {
        case .empty, .all, .starred, .folder(id: _):
            return true
        case .feed(id: _):
            return false
        }
    }

}
#endif
