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
struct ArticleWebView: UIViewRepresentable {
    public let webView: WKWebView
    public let item: CDItem
    public let size: CGSize

    private var feed: CDFeed?
    private var url = URL(fileURLWithPath: "")
    private var content: ArticleWebContent

    private var cancellables = Set<AnyCancellable>()

    public init(webView: WKWebView, item: CDItem, size: CGSize) {
        self.webView = webView
        self.item = item
        self.feed = CDFeed.feed(id: item.feedId)
        self.size = size
        self.content = ArticleWebContent(item: item, size: size)
        url = tempDirectory()?
            .appendingPathComponent("summary")
            .appendingPathExtension("html") ?? URL(fileURLWithPath: "")

            if feed?.preferWeb == true,
               let urlString = item.url,
               let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            } else {
                let request = URLRequest(url: url)
                webView.loadFileRequest(request, allowingReadAccessTo: url.deletingLastPathComponent())
            }
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.scrollView.delegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(webView: webView, content: content)
    }

}
#endif

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    private var content: ArticleWebContent

    private var cancellables = Set<AnyCancellable>()
    private var webView: WKWebView
    private var preferences = Preferences()
    private var isUserScrolling = false
    private var observations = [NSKeyValueObservation]()

    init(webView: WKWebView, content: ArticleWebContent) {
        self.webView = webView
        self.content = content

        super.init()

        observations.append(self.webView.scrollView.observe(\.contentOffset, options: .new, changeHandler: { [weak self] _, value in
            guard let self = self else {
                return
            }
            if self.isUserScrolling {
                return
            }
            if !self.webView.isLoading {
                if self.webView.url?.scheme == "file", self.webView.scrollView.contentOffset != .zero {
                    self.webView.scrollView.setContentOffset(.zero, animated: false)
                }
            }
        }))

        preferences.$marginPortrait.sink { [weak self] newMarginPortrait in
            self?.content.configure()
            self?.webView.reload()
        }
        .store(in: &cancellables)

        preferences.$fontSize.sink { [weak self] newFontSize in
            self?.content.configure()
            self?.webView.reload()
        }
        .store(in: &cancellables)

        preferences.$lineHeight.sink { [weak self] newLineHeight in
            self?.content.configure()
            self?.webView.reload()
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
        if !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(webView.url?.absoluteString ?? "")
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
