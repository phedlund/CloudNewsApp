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

    var webView: WKWebView? {
        didSet {
            setupObservations()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func setupObservations() {
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
            webView.publisher(for: \.url).sink { [weak self] newValue in
                self?.url = newValue
            }
            .store(in: &cancellables)

        }
    }
}
