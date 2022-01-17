//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Foundation
import WebKit

class ArticleModel: ObservableObject, Identifiable {
    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var isLoading = false
    @Published public var title = ""

    private var observations = [NSKeyValueObservation]()
    private var internalWebView: WKWebView?

    var webView: WKWebView {
        get {
            if internalWebView == nil {
                let webConfig = WKWebViewConfiguration()
                webConfig.allowsInlineMediaPlayback = true
                webConfig.mediaTypesRequiringUserActionForPlayback = [.all]
                webConfig.preferences.setValue(true, forKey: "fullScreenEnabled")

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
        observations.append(webView.observe(\.canGoBack, options: .new, changeHandler: {[weak self] _, value in
            self?.canGoBack = value.newValue ?? false
        }))
        observations.append(webView.observe(\.canGoForward, options: .new, changeHandler: { [weak self] _, value in
            self?.canGoForward = value.newValue ?? false
        }))
        observations.append(webView.observe(\.isLoading, options: .new, changeHandler: { [weak self] _, value in
            self?.isLoading = value.newValue ?? false
        }))
        observations.append(webView.observe(\.title, options: .new, changeHandler: {[weak self] _, value in
            self?.title = (value.newValue ?? "") ?? ""
        }))
    }
}


extension ArticleModel: Hashable {

    static func == (lhs: ArticleModel, rhs: ArticleModel) -> Bool {
        return lhs.item.id == rhs.item.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(item.id)
    }

}
