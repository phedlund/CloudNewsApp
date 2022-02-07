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
    @Published public var contentHeight: CGFloat = .zero

    private var cancellables = Set<AnyCancellable>()

    private var observations = [NSKeyValueObservation]()
    private var internalWebView: WKWebView?
    private var shouldListenToResizeNotification = false

    var webView: WKWebView {
        get {
            if internalWebView == nil {
                //Javascript string
                let source = "window.onload=function () {window.webkit.messageHandlers.sizeNotification.postMessage({justLoaded:true,height: document.documentElement.getBoundingClientRect().height});};"
                let source2 = "document.body.addEventListener( 'resize', incrementCounter); function incrementCounter() {window.webkit.messageHandlers.sizeNotification.postMessage({height: document.documentElement.getBoundingClientRect().height});};"

                //UserScript object
                let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

                let script2 = WKUserScript(source: source2, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

                //Content Controller object
                let controller = WKUserContentController()

                //Add script to controller
                controller.addUserScript(script)
                controller.addUserScript(script2)

                //Add message handler reference
                controller.add(self, name: "sizeNotification")

                let webConfig = WKWebViewConfiguration()
                webConfig.preferences.setValue(true, forKey: "fullScreenEnabled")
                webConfig.allowsInlineMediaPlayback = true
                webConfig.mediaTypesRequiringUserActionForPlayback = [.all]
                webConfig.userContentController = controller

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

extension ArticleModel: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let responseDict = message.body as? [String:Any],
              let height = responseDict["height"] as? Float,
                height > .zero else {
                  return
              }
        if contentHeight != CGFloat(height) {
            if let _ = responseDict["justLoaded"] {
                print("just loaded with height \(height)")
                shouldListenToResizeNotification = true
                contentHeight = CGFloat(height)
            }
            else if shouldListenToResizeNotification {
                print("height is \(height)")
                contentHeight = CGFloat(height)
            }
        }
    }

}
