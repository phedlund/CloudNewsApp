//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Combine
import Foundation
import Nuke
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
#if !os(macOS)
                webConfig.allowsInlineMediaPlayback = true
#endif
                webConfig.mediaTypesRequiringUserActionForPlayback = [.all]

                internalWebView = WKWebView(frame: .zero, configuration: webConfig)
                setupObservations()
            }
            return internalWebView!
        }
    }
    var item: CDItem?

    init(item: CDItem?) {
        self.item = item
        guard let item = item,
                let imageLink = item.imageLink,
                !imageLink.isEmpty,
                let _ = URL(withCheck: imageLink) else {
            if let item = item {
                ItemImageFetcher().itemURL(item)
            }
            super.init()
            return
        }
        super.init()
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
#if !os(macOS)
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification, object: nil).sink { [weak self] _ in
            self?.webView.reload()
        }
        .store(in: &cancellables)
#endif
        Task {
            do {
                if let rules = try await ContentBlocker.ruleList() {
                    DispatchQueue.main.async { [weak self] in
                        self?.webView.configuration.userContentController.add(rules)
                    }
                }
            } catch {
                //
            }
        }
    }

}
