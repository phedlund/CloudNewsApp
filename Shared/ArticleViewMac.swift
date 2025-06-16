//
//  ArticleViewMac.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/12/25.
//

import SwiftUI
import WebKit

struct ArticleViewMac: View {
    @Environment(NewsModel.self) private var newsModel

    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var content: ArticleWebContent
    var page: WebPage

    init(content: ArticleWebContent) {
        self.content = content
        let webConfig = WebPage.Configuration()
        page = WebPage(configuration: webConfig)
        if let url = content.url {
            page.load(URLRequest(url: url))
        }
    }

    var body: some View {
        WebView(page)
            .navigationTitle(Text(page.title))
            .toolbar {
                articleToolBarContent()
            }
            .onChange(of: content.url, initial: true) { _, _ in
                Task {
                    if await newsModel.feedPrefersWeb(id: content.item.feedId),
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

    @ToolbarContentBuilder
    func articleToolBarContent() -> some ToolbarContent {
        ToolbarItemGroup {
            Button {
                if let url = page.backForwardList.backList.last?.url {
                    page.load(URLRequest(url: url))
                }
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(page.backForwardList.backList.isEmpty)
            Button {
                //                page.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(page.backForwardList.forwardList.isEmpty)
            Button {
                if page.isLoading {
                    page.stopLoading()
                } else {
                    page.reload()
                }
            } label: {
                if page.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Spacer()
            ShareLinkButton(item: content.item, url: content.url)
                .disabled(page.isLoading)
        }
    }

}

//#Preview {
//    ArticleViewMac()
//}
