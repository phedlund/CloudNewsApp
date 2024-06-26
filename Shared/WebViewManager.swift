//
//  WebViewManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/12/21.
//

import SwiftUI
import WebKit

@dynamicMemberLookup
@MainActor
class WebViewManager: ObservableObject, @preconcurrency Identifiable {
    var id = UUID()

    @Published public var webView: WKWebView {
        didSet {
            setupObservers()
        }
    }

    private var observers: [NSKeyValueObservation] = []

    public init() {
        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: webConfig)
        setupObservers()
    }

    private func setupObservers() {
        func observer<Value>(of keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
            print("Keypath \(keyPath)")
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
