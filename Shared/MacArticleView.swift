//
//  PagerWrapper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/24/22.
//

#if os(macOS)
import Combine
import SwiftUI
import WebKit

struct MacArticleView: View {
    @EnvironmentObject private var settings: Preferences
    @State private var webViewHelper = ItemWebViewHelper()
    let node: Node
    @Binding var itemSelection: ArticleModel.ID?

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false

    init(node: Node, itemSelection: Binding<ArticleModel.ID?>) {
        self.node = node
        _itemSelection = itemSelection
    }

    var body: some View {
        WebView { webView in
            webViewHelper.node = node
            webViewHelper.itemSelection = self.itemSelection
            webViewHelper.webView = webView
            if let urlRequest = webViewHelper.urlRequest {
                webView.load(urlRequest)
                webViewHelper.markItemRead()
            }
        }
        .id(itemSelection) //forces the web view to be recreated to get a unique WKWebView for each article
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onReceive(webViewHelper.$canGoBack) {
            canGoBack = $0
        }
        .onReceive(webViewHelper.$canGoForward) {
            canGoForward = $0
        }
        .onReceive(webViewHelper.$isLoading) {
            isLoading = $0
        }
        .onReceive(webViewHelper.$title) {
            if $0 != title {
                title = $0
            }
        }
        .toolbar(content: articleToolBarContent)
    }

    @ToolbarContentBuilder
    func articleToolBarContent() -> some ToolbarContent {
            ToolbarItemGroup {
                Button {
                    webViewHelper.webView?.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!canGoBack)
                Button {
                    webViewHelper.webView?.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!canGoForward)
                Button {
                    if isLoading {
                        webViewHelper.webView?.stopLoading()
                    } else {
                        webViewHelper.webView?.reload()
                    }
                } label: {
                    if isLoading {
                        Image(systemName: "xmark")
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Spacer()
                if let itemSelection, let item = node.item(for: itemSelection) {
                    ShareLinkView(model: item, url: webViewHelper.url)
                        .disabled(isLoading)
                }
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    if let itemSelection, let item = node.item(for: itemSelection) {
                        ArticleSettingsView(item: item.item!)
                    }
                }
                .disabled(isLoading)
            }
    }

}
#endif
