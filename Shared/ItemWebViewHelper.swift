//
//  ItemWebViewHelper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/3/22.
//

import Combine
import Foundation
import Observation
import WebKit

@Observable
class ItemWebViewHelper {

    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    var title = ""

    var urlRequest: URLRequest?

    var webView: WKWebView? {
        didSet {
            setupObservations()
        }
    }

    private var item: Item?
    private var content: ArticleWebContent?
    private var cancellables = Set<AnyCancellable>()

    func updateItem(item: Item) {
        self.item = item
    }

    func setupObservations() {
        if let webView {
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
#if os(iOS)
            NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification, object: nil).sink { [weak self] _ in
                self?.webView?.reload()
            }
            .store(in: &cancellables)
#endif
            if let feed = item?.feed {
                if feed.preferWeb == true,
                   let urlString = item?.url,
                   let url = URL(string: urlString) {
                    urlRequest = URLRequest(url: url)
                } else {
                    content = ArticleWebContent(item: item)
                    if let url = content?.url {
                        urlRequest = URLRequest(url: url)
                    }
                }
            }
        }
    }

}

extension ItemWebViewHelper: Equatable {

    static func == (lhs: ItemWebViewHelper, rhs: ItemWebViewHelper) -> Bool {
        lhs.urlRequest == rhs.urlRequest
    }

}
