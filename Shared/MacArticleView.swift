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
    var item: ArticleModel

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false

    var body: some View {
        WebView { webView in
            item.webViewHelper.model = item
            item.webViewHelper.webView = webView
            if let urlRequest = item.webViewHelper.urlRequest {
                webView.load(urlRequest)
                item.webViewHelper.markItemRead()
            }
        }
        .id(item.id) //forces the web view to be recreated to get a unique WKWebView for each article
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onReceive(item.webViewHelper.$canGoBack) {
            canGoBack = $0
        }
        .onReceive(item.webViewHelper.$canGoForward) {
            canGoForward = $0
        }
        .onReceive(item.webViewHelper.$isLoading) {
            isLoading = $0
        }
        .onReceive(item.webViewHelper.$title) {
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
                item.webViewHelper.webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!canGoBack)
            Button {
                item.webViewHelper.webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!canGoForward)
            Button {
                if isLoading {
                    item.webViewHelper.webView?.stopLoading()
                } else {
                    item.webViewHelper.webView?.reload()
                }
            } label: {
                if isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            Spacer()
            Group {
                let subject = item.title
                let message = item.displayBody
                if let url = item.webViewHelper.url {
                    if url.scheme?.hasPrefix("file") ?? false {
                        if let urlString = item.item.url, let itemUrl = URL(string: urlString) {
                            ShareLink(item: itemUrl, subject: Text(subject), message: Text(message))
                        }
                    } else {
                        ShareLink(item: url, subject: Text(subject), message: Text(message))
                    }
                } else if !subject.isEmpty {
                    ShareLink(item: subject, subject: Text(subject), message: Text(message))
                }
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    ArticleSettingsView(item: item.item)
                }
            }
            .disabled(isLoading)
        }
    }

}
#endif
