//
//  AppCommands.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/23.
//

import SwiftUI

#if os(macOS)
struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow
    @ObservedObject var model: FeedModel

    @AppStorage(SettingKeys.selectedFeed) private var selectedFeed: Int = 0
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

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
                NotificationCenter.default.post(name: .renameFolder, object: nil)
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
                model.selectPreviousItem()
            }
            .keyboardShortcut("p", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Button("Next") {
                model.selectNextItem()
            }
            .keyboardShortcut("n", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Divider()
            Button(model.currentItem?.unread ?? false ? "Read" : "Unread") {
                Task {
                    try? await NewsManager.shared.markRead(items: [model.currentItem!], unread: !model.currentItem!.unread)
                }
            }
            .keyboardShortcut("u", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Button(model.currentItem?.starred ?? false ? "Unstar" : "Star") {
                Task {
                    try? await NewsManager.shared.markStarred(item: model.currentItem!, starred: !model.currentItem!.starred)
                }
            }
            .keyboardShortcut("s", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Divider()
            Button("Copy Link") {
                if let urlString = model.currentItem?.url, let url = URL(string: urlString) {
                    MacClipboard.set(url: url)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(isCopyCurrentLinkDisabled())
            Divider()
            Group { // Needed to get around the SwiftUI sub-view limitation
                Menu {
                    Button("Increase") {
                        if fontSize < Constants.ArticleSettings.maxFontSize {
                            fontSize += 1
                        }
                    }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(isCurrentItemDisabled())
                    Button("Decrease") {
                        if fontSize > Constants.ArticleSettings.minFontSize {
                            fontSize -= 1
                        }
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(isCurrentItemDisabled())
                    Divider()
                    Button("Restore") {
                        fontSize = Constants.ArticleSettings.defaultFontSize
                    }
                    .keyboardShortcut("0", modifiers: [.command, .control])
                    .disabled(isCurrentItemDisabled())
                } label: {
                    Text("Font Size")
                }
                Menu {
                    Button("Increase") {
                        if lineHeight < Constants.ArticleSettings.maxLineHeight {
                            lineHeight += 0.2
                        }
                    }
                    .keyboardShortcut("+", modifiers: [.command, .control])
                    .disabled(isCurrentItemDisabled())
                    Button("Decrease") {
                        if lineHeight > Constants.ArticleSettings.minLineHeight {
                            lineHeight -= 0.2
                        }
                    }
                    .keyboardShortcut("-", modifiers: [.command, .control])
                    .disabled(isCurrentItemDisabled())
                } label: {
                    Text("Line Spacing")
                }
                Menu {
                    Button("Increase") {
                        if marginPortrait > Constants.ArticleSettings.minMarginWidth {
                            marginPortrait -= 5
                        }
                    }
                    .keyboardShortcut("+", modifiers: [.command, .option])
                    .disabled(isCurrentItemDisabled())
                    Button("Decrease") {
                        if marginPortrait < Constants.ArticleSettings.maxMarginWidth {
                            marginPortrait += 5
                        }
                    }
                    .keyboardShortcut("-", modifiers: [.command, .option])
                    .disabled(isCurrentItemDisabled())
                } label: {
                    Text("Margin")
                }
            }
        }
        CommandGroup(after: .help) {
            Divider()
            Link(destination: supportURL) {
                Label("Contact", systemImage: "mail")
            }
            Link(destination: URL(string: Constants.website)!) {
                Label("Web Site", systemImage: "link")
            }
            Divider()
            Button("Acknowledgements...") {
                openWindow(id: ModalSheet.acknowledgement.rawValue)
            }
        }
    }

    private func isCurrentItemDisabled() -> Bool {
        return model.currentItemID == nil
    }

    private func isCopyCurrentLinkDisabled() -> Bool {
        if model.currentItemID == nil {
            return true
        }
        if let urlString = model.currentItem?.url, let _ = URL(string: urlString) {
            return false
        }
        return true
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

    var supportURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Constants.email
        components.queryItems = [URLQueryItem(name: "subject", value: Constants.subject),
                                 URLQueryItem(name: "body", value: Constants.message)]
        if let mailURL = components.url {
            return mailURL
        } else {
            return URL(string: "data:null")!
        }
    }

}

public class MacClipboard {
    public static func set(text: String?) {
        if let text {
            let pasteBoard = NSPasteboard.general
            pasteBoard.clearContents()
            pasteBoard.setString(text, forType: .string)
        }
    }

    public static func set(url: URL?) {
        guard let url = url else { return }
        let pasteBoard = NSPasteboard.general

        pasteBoard.clearContents()
        pasteBoard.setData(url.dataRepresentation, forType: .URL)
    }

    public static func set(urlContent: URL?) {
        guard let url = urlContent,
              let nsImage = NSImage(contentsOf: url)
        else { return }

        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.writeObjects([nsImage])
    }

    public static func clear() {
        NSPasteboard.general.clearContents()
    }
}

#endif
