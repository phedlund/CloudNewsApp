//
//  WebViewManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/12/21.
//

import Combine
import SwiftUI
import WebKit

enum WebViewType {
    case article
    case login
}

class WebViewManager: ObservableObject {
    var type: WebViewType

    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }

    private var observers: [NSKeyValueObservation] = []

    public init(type: WebViewType) {
        self.type = type
        let webConfig = WKWebViewConfiguration ()
        switch type {
        case .article:
            webConfig.allowsInlineMediaPlayback = true
            webConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        case .login:
            webConfig.websiteDataStore = .nonPersistent()
        }
        self.webView = WKWebView(frame: .zero, configuration: webConfig)
        setupObservers()
    }

    private func setupObservers() {
        func observer<Value>(of keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
            return webView.observe(keyPath, options: [.prior]) { _, change in
                if change.isPrior {
                    self.objectWillChange.send()
                }
            }
        }

        observers = [
            observer(of: \.title),
            observer(of: \.url),
            observer(of: \.isLoading),
            observer(of: \.serverTrust),
            observer(of: \.canGoBack),
            observer(of: \.canGoForward)
        ]
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<WKWebView, T>) -> T {
        webView[keyPath: keyPath]
    }

}
