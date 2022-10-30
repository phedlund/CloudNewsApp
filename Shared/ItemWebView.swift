//
//  ItemWebView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2022-07-02.
//  Copyright © 2022 Peter Hedlund. All rights reserved.
//

#if os(iOS)
typealias WebViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias WebViewRepresentable = NSViewRepresentable
#endif

#if os(iOS) || os(macOS)
import Combine
import SwiftUI
import WebKit

public struct WebView: WebViewRepresentable {
    @AppStorage(SettingKeys.adBlock) var adBlock = true

    private let configuration: (WKWebView) -> Void

    init(configuration: @escaping (WKWebView) -> Void = { _ in }) {
        self.configuration = configuration
    }

#if os(iOS)
    public func makeUIView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) { }
#endif

#if os(macOS)
    public func makeNSView(context: Context) -> WKWebView {
        makeView(context: context)
    }

    public func updateNSView(_ view: WKWebView, context: Context) { }

#endif

    public func makeCoordinator() -> ItemWebViewCoordinator {
        ItemWebViewCoordinator()
    }

}

private extension WebView {

    func makeView(context: Context) -> WKWebView {
        let webConfig = WKWebViewConfiguration()
        webConfig.preferences.setValue(true, forKey: "fullScreenEnabled")
#if os(iOS)
        webConfig.allowsInlineMediaPlayback = true
#endif
        webConfig.mediaTypesRequiringUserActionForPlayback = [.all]
        let view = WKWebView(frame: .zero, configuration: webConfig)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
#if os(iOS)
        view.scrollView.showsHorizontalScrollIndicator = false
        view.scrollView.contentInset = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 0)
#endif
        if adBlock {
            Task {
                do {
                    if let rules = try await ContentBlocker.ruleList() {
                        DispatchQueue.main.async {
                            view.configuration.userContentController.add(rules)
                        }
                    }
                } catch {
                    //
                }
            }
        }
        configuration(view)
        return view
    }

}

#endif

public class ItemWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let scheme = await webView.url?.scheme {
            if scheme == "file" || scheme.hasPrefix("itms") {
                if let url = navigationAction.request.url {
                    if url.absoluteString.contains("itunes.apple.com") || url.absoluteString.contains("apps.apple.com") {
                        //TODO                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        return .cancel
                    }
                }
            }
        }
        return .allow
    }

    public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // uiDelegate needed to open target="_blank" links
        if !(navigationAction.targetFrame?.isMainFrame ?? false) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(webView.url?.absoluteString ?? "")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        webView.evaluateJavaScript("document.documentElement.outerHTML.toString()",
//                                   completionHandler: { (html: Any?, error: Error?) in
//            print(html)
//        })
    }

}
