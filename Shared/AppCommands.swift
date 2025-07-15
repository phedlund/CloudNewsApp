//
//  AppCommands.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/23.
//

import SwiftData
import SwiftUI

struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow
    let newsModel: NewsModel

    @AppStorage(SettingKeys.selectedFeed) private var selectedFeed: Int = 0
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @Binding var isShowingAddFeed: Bool
    @Binding var isShowingFeedSettings: Bool
    @Binding var isShowingAddFolder: Bool
    @Binding var isShowingAcknowledgements: Bool

    @CommandsBuilder var body: some Commands {
        SidebarCommands()
        CommandGroup(after: .sidebar) {
            Divider()
            MarkReadButton()
                .environment(newsModel)
            Divider()
            Button {
                NotificationCenter.default.post(name: .syncNews, object: nil)
            } label: {
                Label {
                    Text("Refresh")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .keyboardShortcut("r")
            Divider()
        }
        CommandMenu("Folder") {
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.addFolder.rawValue)
#else
                isShowingAddFolder.toggle()
#endif
            } label: {
                Label {
                    Text("New Folder...")
                } icon: {
                    Image(systemName: "folder.badge.plus")
                }
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button {
                NotificationCenter.default.post(name: .renameFolder, object: nil)
            } label: {
                Label {
                    Text("Rename...")
                } icon: {
                    Image(systemName: "folder.badge.gearshape")
                }
            }
            .disabled(isFolderRenameDisabled())
            Divider()
            Button {
                NotificationCenter.default.post(name: .deleteFolder, object: nil)
            } label: {
                Label {
                    Text("Delete Folder...")
                } icon: {
                    Image(systemName: "folder.badge.minus")
                }
            }
            .disabled(isFolderRenameDisabled())
        }
        CommandMenu("Feed") {
            Button {
#if os(macOS)
                openWindow(id: ModalSheet.addFeed.rawValue)
#else
                isShowingAddFeed.toggle()
#endif
            } label: {
                Label {
                    Text("New Feed...")
                } icon: {
                    Image(systemName: "document.badge.plus")
                }
            }
            .keyboardShortcut("n")
            Divider()
            Button {
                switch newsModel.currentNodeType {
                case .empty, .all, .unread, .starred, .folder(id: _):
                    break
                case .feed(id: _):
#if os(macOS)
                    openWindow(id: ModalSheet.feedSettings.rawValue)
#else
                    isShowingFeedSettings.toggle()
#endif
                }
            } label: {
                Label {
                    Text("Feed Settings...")
                } icon: {
                    Image(systemName: "document.badge.gearshape")
                }
            }
            .disabled(isFeedSettingsDisabled())
            Divider()
            Button {
                NotificationCenter.default.post(name: .deleteFeed, object: nil)
            } label: {
                Label {
                    Text("Delete Feed...")
                } icon: {
                    Image(systemName: "delete.left")
                }
            }
            .disabled(isFeedSettingsDisabled())
        }
        CommandMenu("Article") {
            Button {
                NotificationCenter.default.post(name: .previousArticle, object: nil)
            } label: {
                Label {
                    Text("Previous")
                } icon: {
                    Image(systemName: "arrow.backward")
                }
            }
            .keyboardShortcut("p", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Button {
                NotificationCenter.default.post(name: .nextArticle, object: nil)
            } label: {
                Label {
                    Text("Next")
                } icon: {
                    Image(systemName: "arrow.forward")
                }
            }
            .keyboardShortcut("n", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Divider()
            Button {
                Task {
                    newsModel.toggleCurrentItemRead()
                }
            } label: {
                Label {
                    Text(newsModel.currentItem?.unread ?? false ? "Read" : "Unread")
                } icon: {
                    Image(systemName: newsModel.currentItem?.unread ?? false ? "eye" : "eye.slash")
                }
            }
            .keyboardShortcut("u", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Button {
                Task {
                    try? await newsModel.toggleCurrentItemStarred()
                }
            } label: {
                Label {
                    Text(newsModel.currentItem?.starred ?? false ? "Unstar" : "Star")
                } icon: {
                    Image(systemName: newsModel.currentItem?.starred ?? false ? "star" : "star.fill")
                }
            }
            .keyboardShortcut("s", modifiers: [.control])
            .disabled(isCurrentItemDisabled())
            Divider()
            Button {
                if let urlString = newsModel.currentItem?.url, let url = URL(string: urlString) {
#if os(macOS)
                    MacClipboard.set(url: url)
#else
                    UIPasteboard.general.url = url
#endif
                }
            } label: {
                Label {
                    Text("Copy Link")
                } icon: {
                    Image(systemName: "link")
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
        CommandGroup(replacing: .help) {
            Divider()
            Link(destination: supportURL) {
                Label("Contact", systemImage: "mail")
            }
            Link(destination: URL(string: Constants.website)!) {
                Label("Web Site", systemImage: "link")
            }
            Divider()
            Button {
                openWindow(id: ModalSheet.acknowledgement.rawValue)
            } label: {
                Label {
                    Text("Acknowledgements...")
                } icon: {
                    Image(systemName: "hand.thumbsup")
                }
            }
        }
    }

    private func isCurrentItemDisabled() -> Bool {
        return newsModel.currentItem == nil
    }

    private func isCopyCurrentLinkDisabled() -> Bool {
        guard let item = newsModel.currentItem else {
            return true
        }
        if let urlString = item.url, let _ = URL(string: urlString) {
            return false
        }
        return true
    }

    private func isFolderRenameDisabled() -> Bool {
        switch newsModel.currentNodeType {
        case .empty, .all, .unread, .starred, .feed(id: _):
            return true
        case .folder(id: _):
            return false
        }
    }

    private func isFeedSettingsDisabled() -> Bool {
        switch newsModel.currentNodeType {
        case .empty, .all, .unread, .starred, .folder(id: _):
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

#if os(macOS)
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
