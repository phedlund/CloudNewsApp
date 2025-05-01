//
//  WebViewReader.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/27/24.
//

import Combine
import Foundation
import SwiftUI
import WebKit

@Observable
class PageViewProxy {
    var scrollId: Int64?
    var canGoBack = false
    var goBack = false
    var canGoForward = false
    var goForward = false
    var isLoading = false
    var reload = false
    var title = ""
    var url: URL?
}

@MainActor
public final class WebViewProxy: ObservableObject {
    private(set) weak var webView: WKWebView?

    @Published public private(set) var canGoBack = false
    @Published public private(set) var canGoForward = false
    @Published public private(set) var isLoading = false
    @Published public private(set) var title = ""
    @Published public private(set) var url: URL?

    private var tasks = [Task<Void, Never>]()

    func setup(webView: WKWebView) {
        self.webView = webView
        observe(webView)
    }

    private func observe(_ webView: WKWebView) {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        tasks = [
            Task { @MainActor in
                for await value in webView.publisher(for: \.title).bufferedValues() {
                    self.title = value ?? "Untitled"
                }
            },
            Task { @MainActor in
                for await value in webView.publisher(for: \.isLoading).bufferedValues() {
                    self.isLoading = value
                }
            },
            Task { @MainActor in
                for await value in webView.publisher(for: \.url).bufferedValues() {
                    self.url = value
                }
            },
            Task { @MainActor in
                for await value in webView.publisher(for: \.canGoBack).bufferedValues() {
                    self.canGoBack = value
                }
            },
            Task { @MainActor in
                for await value in webView.publisher(for: \.canGoForward).bufferedValues() {
                    self.canGoForward = value
                }
            }
        ]
    }
}

public struct WebViewReader<Content: View>: View {
    @StateObject private var proxy = WebViewProxy()

    private let content: (WebViewProxy) -> Content

    init(@ViewBuilder content: @escaping (WebViewProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(proxy)
    }
}
