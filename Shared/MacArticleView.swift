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
    var item: Item

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false

    var body: some View {
        WebView { webView in
            item.webViewHelper.updateItem(item: item)
            item.webViewHelper.webView = webView
        }
        .id(item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: item.webViewHelper.urlRequest) { _, newValue in
             if let newValue {
                item.webViewHelper.webView?.load(newValue)
            }
        }
        .task {
            if let request = item.webViewHelper.urlRequest {
                item.webViewHelper.webView?.load(request)
            }
        }
        .toolbar {
            articleToolBarContent(item: item)
        }
    }

    @ToolbarContentBuilder
    func articleToolBarContent(item: Item) -> some ToolbarContent {
        ToolbarItemGroup {
            Button {
                item.webViewHelper.webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!item.webViewHelper.canGoBack)
            Button {
                item.webViewHelper.webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!item.webViewHelper.canGoForward)
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
            ShareLinkButton(item: item)
                .disabled(item.webViewHelper.isLoading)
        }
    }

}
#endif
