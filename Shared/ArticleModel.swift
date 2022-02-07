//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Combine
import Foundation
import WebKit

class ArticleModel: NSObject, ObservableObject, Identifiable {
    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var isLoading = false
    @Published public var title = ""

    private var cancellables = Set<AnyCancellable>()

    private var observations = [NSKeyValueObservation]()
    private var internalWebView: WKWebView?
    private var shouldListenToResizeNotification = false

    var webView: WKWebView {
        get {
            if internalWebView == nil {
                let webConfig = WKWebViewConfiguration()
                webConfig.preferences.setValue(true, forKey: "fullScreenEnabled")
                webConfig.allowsInlineMediaPlayback = true
                webConfig.mediaTypesRequiringUserActionForPlayback = [.all]

                internalWebView = WKWebView(frame: .zero, configuration: webConfig)
                setupObservations()
            }
            return internalWebView!
        }
    }
    var item: CDItem

    init(item: CDItem) {
        self.item = item
    }

    private func setupObservations() {
        webView.publisher(for: \.canGoBack).sink { [weak self] newValue in
            self?.canGoBack = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.canGoForward).sink { [weak self] newValue in
            self?.canGoForward = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.isLoading).sink { [weak self] newValue in
            self?.isLoading = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.title).sink { [weak self] newValue in
            if let newTitle = newValue, !newTitle.isEmpty {
                self?.title = newTitle
            }
        }
        .store(in: &cancellables)
    }
}
