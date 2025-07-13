//
//  PadCommands.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/25.
//

import SwiftUI

struct PadCommands: Commands {
    @Environment(\.openWindow) var openWindow
    let newsModel: NewsModel

    @AppStorage(SettingKeys.selectedFeed) private var selectedFeed: Int = 0
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @Binding var isShowingAcknowledgements: Bool

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

    @CommandsBuilder var body: some Commands {
        SidebarCommands()
        CommandGroup(after: .sidebar) {
            Divider()
            MarkReadButton()
                .environment(newsModel)
            Divider()
            Button("Refresh") {
                NotificationCenter.default.post(name: .syncNews, object: nil)
            }
            .keyboardShortcut("r")
            Divider()
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
            Button("Acknowledgements...") {
                isShowingAcknowledgements.toggle()
            }
        }
    }
}
