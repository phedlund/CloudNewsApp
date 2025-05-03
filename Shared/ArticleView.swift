//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var content: ArticleWebContent

    @Bindable var pageViewReader: PageViewProxy

    init(content: ArticleWebContent, pageViewReader: PageViewProxy) {
        self.content = content
        self.pageViewReader = pageViewReader
    }

    var body: some View {
        WebViewReader { reader in
            WebView { webView in
                reader.setup(webView: webView)
            }
            .id(content.item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .safeAreaPadding([.top], 40)
            .task {
                pageViewReader.title = reader.title
                if let feed = content.item.feed {
                    if feed.preferWeb == true,
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
            .background {
                Color.phWhiteBackground
                    .ignoresSafeArea(edges: .vertical)
            }
            .onChange(of: pageViewReader.scrollId) { oldValue, newValue in
                print("got scroll id: \(newValue ?? -1)")
                if newValue == content.item.id {
                    pageViewReader.title = reader.title
                    pageViewReader.canGoBack = reader.canGoBack
                    pageViewReader.canGoForward = reader.canGoForward
                    pageViewReader.isLoading = reader.isLoading
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
        }
    }

}
