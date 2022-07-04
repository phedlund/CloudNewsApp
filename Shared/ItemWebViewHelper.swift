//
//  ItemWebViewHelper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/3/22.
//

import Combine
import Foundation
import WebKit

class ItemWebViewHelper: ObservableObject {

    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var isLoading = false
    @Published public var title = ""
    @Published public var url: URL?

    var node: Node?
    var itemSelection: ArticleModel.ID?
    var urlRequest: URLRequest?

    var webView: WKWebView? {
        didSet {
            setupObservations()
        }
    }

    private var content: ArticleWebContent?
    private var cancellables = Set<AnyCancellable>()

    func markItemRead() {
        if let node, let itemSelection, let model = node.item(for: itemSelection), let item = model.item {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

    private func setupObservations() {
        if let webView, let node, let itemSelection, let model = node.item(for: itemSelection) {
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
            webView.publisher(for: \.url).sink { [weak self] newValue in
                self?.url = newValue
            }
            .store(in: &cancellables)

            if let item = model.item {
                let feed = CDFeed.feed(id: item.feedId)
                if feed?.preferWeb == true,
                   let urlString = model.item?.url,
                   let url = URL(string: urlString) {
                    urlRequest = URLRequest(url: url)
                } else {
                    content = ArticleWebContent(item: item)
                    content?.$url.sink { [weak self] newURL in
                        guard let self, let newURL else { return }
                        self.webView?.reload()
                        self.urlRequest = URLRequest(url: newURL)
                        print("Created request for \(newURL.absoluteString)")
                    }
                    .store(in: &cancellables)
                }
            }

        }

    }
}