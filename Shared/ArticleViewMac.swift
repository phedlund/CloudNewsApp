//
//  ArticleViewMac.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/12/25.
//

import SwiftUI
import WebKit

#if os(macOS)
struct ArticleViewMac: View {
    @Environment(NewsModel.self) private var newsModel

    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var content: ArticleWebContent

    init(content: ArticleWebContent) {
        self.content = content
        content.reloadItemSummary()
    }

    var body: some View {
        WebView(content.page)
            .navigationTitle(Text(content.page.title))
            .toolbar {
                articleToolBarContent()
            }
            .onChange(of: fontSize) {
                content.reloadItemSummary()
            }
            .onChange(of: lineHeight) {
                content.reloadItemSummary()
            }
            .onChange(of: marginPortrait) {
                content.reloadItemSummary()
            }
    }

    @ToolbarContentBuilder
    func articleToolBarContent() -> some ToolbarContent {
        ToolbarItemGroup {
            Button {
                if let url = content.page.backForwardList.backList.last?.url {
                    content.page.load(URLRequest(url: url))
                }
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(content.page.backForwardList.backList.isEmpty)
            Button {
                //                page.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(content.page.backForwardList.forwardList.isEmpty)
            Button {
                if content.page.isLoading {
                    content.page.stopLoading()
                } else {
                    content.page.reload()
                }
            } label: {
                if content.page.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Spacer()
            ShareLinkButton(item: newsModel.currentItem, url: content.page.url)
                .disabled(content.page.isLoading)
        }
    }

}
#endif
//#Preview {
//    ArticleViewMac()
//}
