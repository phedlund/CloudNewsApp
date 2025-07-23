//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

#if !os(macOS)
import SwiftUI
import WebKit

struct ArticleView: View, @MainActor Equatable {
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var content: ArticleWebContent
    var page: WebPage

    @Bindable var pageViewReader: PageViewProxy

    static func == (lhs: ArticleView, rhs: ArticleView) -> Bool {
        lhs.content.item.id == rhs.content.item.id
    }

    init(content: ArticleWebContent, pageViewReader: PageViewProxy) {
        self.content = content
        self.pageViewReader = pageViewReader
        let webConfig = WebPage.Configuration()
        ContentBlocker.rules { rules in
            if let rules {
                Task { @MainActor in
                    webConfig.userContentController.add(rules)
                }
            }
        }
        page = WebPage(configuration: webConfig, navigationDecider: NavigationDecider())
        if let feed = content.item.feed {
            if feed.preferWeb == true,
               let urlString = content.item.url,
               let url = URL(string: urlString) {
                page.load(URLRequest(url: url))
            } else {
                if let url = content.url {
                    page.load(URLRequest(url: url))
                }
            }
        }
    }

    var body: some View {
        WebView(page)
            .webViewBackForwardNavigationGestures(.disabled)
            .scrollIndicators(.visible, axes: .vertical)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding([.top], 40)
            .onChange(of: pageViewReader.scrollId) { oldValue, newValue in
                if newValue == content.item.id {
                    pageViewReader.page = page
                    pageViewReader.itemId = newValue
                }
            }
            .onChange(of: fontSize) {
                content.reloadItemSummary()
                page.reload()
            }
            .onChange(of: lineHeight) {
                content.reloadItemSummary()
                page.reload()
            }
            .onChange(of: marginPortrait) {
                content.reloadItemSummary()
                page.reload()
            }
    }

}
#endif

