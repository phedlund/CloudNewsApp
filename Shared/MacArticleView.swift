//
//  PagerWrapper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/24/22.
//

#if os(macOS)
import Combine
import CoreData
import SwiftUI
import WebKit

struct MacArticleView: View {
    @Environment(NewsModel.self) private var newsModel

    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    var content: ArticleWebContent

    let pageViewReader = PageViewProxy()

    init(content: ArticleWebContent) {
        self.content = content
    }

    var body: some View {
        WebViewReader { reader in
            WebView { webView in
                reader.setup(webView: webView)
                pageViewReader.title = reader.title
                Task {
                    if await newsModel.feedPrefersWeb(id: content.item.feedId),
                        let urlString = content.item.url,
                        let url = URL(string: urlString) {
                            pageViewReader.url = url
                            reader.webView?.load(URLRequest(url: url))
                    } else {
                        if let url = content.url {
                            pageViewReader.url = url
                            reader.webView?.load(URLRequest(url: url))
                        }
                    }
                }
            }
            .id(content.item.id) //forces the web view to be recreated to get a unique WKWebView for each article
            .navigationTitle(title)
            .background {
                Color.phWhiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onChange(of: content.url, initial: true) { _, _ in
                pageViewReader.title = reader.title
                Task {
                    if await newsModel.feedPrefersWeb(id: content.item.feedId),
                        let urlString = content.item.url,
                        let url = URL(string: urlString) {
                            pageViewReader.url = url
                            reader.webView?.load(URLRequest(url: url))
                    } else {
                        if let url = content.url {
                            pageViewReader.url = url
                            reader.webView?.load(URLRequest(url: url))
                        }
                    }
                }
            }
            .onChange(of: reader.canGoBack) { _, newValue in
                pageViewReader.canGoBack = newValue
            }
            .onChange(of: pageViewReader.goBack) { _, newValue in
                if newValue == true {
                    reader.webView?.goBack()
                }
                pageViewReader.goBack = false
            }
            .onChange(of: reader.canGoForward) { _, newValue in
                pageViewReader.canGoForward = newValue
            }
            .onChange(of: pageViewReader.goForward) { _, newValue in
                if newValue == true {
                    reader.webView?.goForward()
                }
                pageViewReader.goForward = false
            }
            .onChange(of: reader.isLoading) { _, newValue in
                pageViewReader.isLoading = newValue
            }
            .onChange(of: pageViewReader.reload) { _, newValue in
                if newValue == true {
                    reader.webView?.reload()
                } else {
                    reader.webView?.stopLoading()
                }
            }
            .onChange(of: fontSize) {
                content.reloadItemSummary()
                reader.webView?.reload()
            }
            .onChange(of: lineHeight) {
                content.reloadItemSummary()
                reader.webView?.reload()
            }
            .onChange(of: marginPortrait) {
                content.reloadItemSummary()
                reader.webView?.reload()
            }
            .toolbar {
                articleToolBarContent(reader: reader)
            }
        }
    }

    @ToolbarContentBuilder
    func articleToolBarContent(reader: WebViewProxy) -> some ToolbarContent {
        ToolbarItemGroup {
            Button {
                reader.webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!reader.canGoBack)
            Button {
                reader.webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!reader.canGoForward)
            Button {
                if isLoading {
                    reader.webView?.stopLoading()
                } else {
                    reader.webView?.reload()
                }
            } label: {
                if isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Spacer()
            ShareLinkButton(item: content.item, url: content.url)
                .disabled(isLoading)
        }
    }

}
#endif
