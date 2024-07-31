//
//  WebViewReader.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/27/24.
//

import Foundation
import SwiftUI
import WebKit

@Observable
class PageViewProxy: @unchecked Sendable {
    var scrollId: Int64 = 0
    var canGoBack = false
    var goBack = false
    var canGoForward = false
    var goForward = false
    var isLoading = false
    var reload = false
    var title = ""
}

@Observable
class WebViewProxy: @unchecked Sendable, Equatable {
    static func == (lhs: WebViewProxy, rhs: WebViewProxy) -> Bool {
        lhs.item == rhs.item
    }

    private(set) weak var webView: WKWebView?

    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var title = ""
    var urlRequest: URLRequest?

    private var item: Item?
    private var content: ArticleWebContent?
    private var task: Task<Void, Never>?

    func setup(item: Item, webView: WKWebView) {
        self.item = item
        self.webView = webView
        if let feed = item.feed {
            if feed.preferWeb == true,
               let urlString = item.url,
               let url = URL(string: urlString) {
                urlRequest = URLRequest(url: url)
            } else {
                content = ArticleWebContent(item: item)
                if let url = content?.url {
                    urlRequest = URLRequest(url: url)
                }
            }
        }
        observe(webView)
    }

    private func observe(_ webView: WKWebView) {
        task?.cancel()
        task = Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    for await value in webView.publisher(for: \.title).bufferedValues() {
                        self.title = value ?? "Untitled"
                    }
                }
                group.addTask { @MainActor in
                    for await value in webView.publisher(for: \.isLoading).bufferedValues() {
                        self.isLoading = value
                    }
                }
                group.addTask { @MainActor in
                    for await value in webView.publisher(for: \.canGoBack).bufferedValues() {
                        self.canGoBack = value
                    }
                }

                group.addTask { @MainActor in
                    for await value in webView.publisher(for: \.canGoForward).bufferedValues() {
                        self.canGoForward = value
                    }
                }
            }
        }
    }

}

public struct WebViewReader<Content: View>: View {
    @State private var proxy = WebViewProxy()

    private let content: (WebViewProxy) -> Content

    init(@ViewBuilder content: @escaping (WebViewProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(proxy)
    }
}
