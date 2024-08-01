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

    var item: Item
    @Bindable var pageViewReader: PageViewProxy

    var body: some View {
        WebViewReader { reader in
            WebView { webView in
                reader.setup(item: item, webView: webView)
            }
            .id(item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .safeAreaPadding([.top], 20)
            .onAppear {
                pageViewReader.title = reader.title
            }
            .background {
                Color.phWhiteBackground
                    .ignoresSafeArea(edges: .vertical)
            }
            .onChange(of: pageViewReader.scrollId) { oldValue, newValue in
                print("got scroll id: \(newValue)")
                if newValue == item.id {
                    pageViewReader.title = reader.title
                    pageViewReader.canGoBack = reader.canGoBack
                    pageViewReader.canGoForward = reader.canGoForward
                    pageViewReader.isLoading = reader.isLoading
                }
            }
            .onChange(of: reader.urlRequest) { oldValue, newValue in
                if newValue != oldValue, let urlRequest = reader.urlRequest {
                    reader.webView?.load(urlRequest)
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
                reader.webView?.reload()
            }
            .onChange(of: lineHeight) {
                reader.webView?.reload()
            }
            .onChange(of: marginPortrait) {
                reader.webView?.reload()
            }
            .task {
                if let request = reader.urlRequest {
                    reader.webView?.load(request)
                }
            }
        }
    }

    @ToolbarContentBuilder
    func viewToolBarContent(reader: WebViewProxy) -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
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
                if reader.isLoading {
                    reader.webView?.stopLoading()
                } else {
                    reader.webView?.reload()
                }
            } label: {
                if reader.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}
