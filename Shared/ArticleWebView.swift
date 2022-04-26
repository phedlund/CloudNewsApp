//
//  ArticleWebView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/29/21.
//

import SwiftUI
import Combine
import WebKit

#if os(macOS)
struct ArticleWebView: NSViewRepresentable {
    public let webView: WKWebView

    public init(webView: WKWebView) {
      self.webView = webView
    }

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ uiView: WKWebView, context: Context) {
    }

}
#else
struct ArticleWebView: UIViewRepresentable, Equatable {

    @ObservedObject var model: ArticleModel

    let content: ArticleWebContent

    public init(model: ArticleModel) {
        print(model.item?.title ?? "")
        self.model = model
        self.content = ArticleWebContent(item: model.item)
    }

    static func == (lhs: ArticleWebView, rhs: ArticleWebView) -> Bool {
        let isTheSame = lhs.model == rhs.model
        return isTheSame
    }

    func makeUIView(context: Context) -> WKWebView {
        model.webView.navigationDelegate = context.coordinator
        model.webView.uiDelegate = context.coordinator
        model.webView.allowsBackForwardNavigationGestures = false
        model.webView.scrollView.showsHorizontalScrollIndicator = false
        model.webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 0)
        if let item = model.item {
            let feed = CDFeed.feed(id: item.feedId)
            if feed?.preferWeb == true,
               let urlString = model.item?.url,
               let url = URL(string: urlString) {
                model.webView.load(URLRequest(url: url))
            } else {
                let url = tempDirectory()?
                    .appendingPathComponent("summary_\(item.id)")
                    .appendingPathExtension("html") ?? URL(fileURLWithPath: "")

                let request = URLRequest(url: url)
                model.webView.loadFileRequest(request, allowingReadAccessTo: url.deletingLastPathComponent())
            }
        }
        return model.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

}
#endif

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    @ObservedObject private var content: ArticleWebContent

    private let parent: ArticleWebView
    private var cancellables = Set<AnyCancellable>()
    private var isUserScrolling = false
    private var requestUrl = URL(string: "")

    init(_ parent: ArticleWebView) {
        self.parent = parent
        self.content = parent.content
        super.init()

        content.$refreshToken.sink { [weak self] _ in
            guard let self = self else { return }
            self.parent.model.webView.reload()
        }
        .store(in: &cancellables)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if webView.url?.scheme == "file" || webView.url?.scheme?.hasPrefix("itms") ?? false {
            if let url = navigationAction.request.url {
                if url.absoluteString.contains("itunes.apple.com") || url.absoluteString.contains("apps.apple.com") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        decisionHandler(.allow);
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // uiDelegate needed to open target="_blank" links
        if !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(webView.url?.absoluteString ?? "")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()",
//                                   completionHandler: { (html: Any?, error: Error?) in
//            print(html)
//        })
    }


    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isDragging || scrollView.isDecelerating {
            isUserScrolling = true
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
    }

}
