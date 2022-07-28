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
    @StateObject private var feedModel = FeedModel()

#if !os(macOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
#else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let syncTimer = SyncTimer()
#endif

    var body: some Scene {
        WindowGroup {
            ContentView(model: feedModel, settings: settings)
        }
#if os(macOS)
        .defaultSize(width: 1000, height: 650)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            AppCommands(model: feedModel)
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
            MarkReadButton(node: model.currentNode)
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
            Button("New Folder...") {
                openWindow(id: ModalSheet.addFolder.rawValue)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
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
            Button("Delete Folder...") {
                NotificationCenter.default.post(name: .deleteFolder, object: nil)
            }
            .keyboardShortcut(.delete)
            .disabled(isFolderRenameDisabled())
        }
        CommandMenu("Feed") {
            Button("New Feed...") {
                openWindow(id: ModalSheet.addFeed.rawValue)
            }
            .keyboardShortcut("n")
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
            Button {
                NotificationCenter.default.post(name: .deleteFeed, object: nil)
            } label: {
                Text("Delete Feed...")
            }
            .keyboardShortcut(.delete)
            .disabled(isFeedSettingsDisabled())
        }
        CommandMenu("Article") {
            Button("Previous") {
                if let item = model.currentItem {
                    model.updateCurrentItem(model.currentNode.items.element(before: item))
                }
            }
            .keyboardShortcut("p", modifiers: [])
            .disabled(isCurrentItemDisabled())
            Button("Next") {
                if let item = model.currentItem {
                    model.updateCurrentItem(model.currentNode.items.element(after: item))
                }
            }
            .keyboardShortcut("n", modifiers: [])
            .disabled(isCurrentItemDisabled())
            Divider()
            Button(model.currentItem?.unread ?? false ? "Read" : "Unread") {
                Task {
                    try? await NewsManager.shared.markRead(items: [model.currentItem!.item!], unread: !model.currentItem!.item!.unread)
                }
            }
            .keyboardShortcut("u", modifiers: [])
            .disabled(isCurrentItemDisabled())
            Button(model.currentItem?.starred ?? false ? "Unstar" : "Star") {
                Task {
                    try? await NewsManager.shared.markStarred(item: model.currentItem!.item!, starred: !model.currentItem!.starred)
                }
            }
            .keyboardShortcut("s", modifiers: [])
            .disabled(isCurrentItemDisabled())
//            Divider()
//            Button("Summary") {
//                print("Favorite selected")
//            }
//            .keyboardShortcut("1")
//            Button("Web") {
//                print("Category selected")
//            }
//            .keyboardShortcut("2")
        }
    }

    private func isCurrentItemDisabled() -> Bool {
        return model.currentItem == nil
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
