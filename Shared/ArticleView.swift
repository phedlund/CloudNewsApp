//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    var item: Item

    @Binding var webViewHelper: ItemWebViewHelper
    @State private var webView = WKWebView()

    var body: some View {
        GeometryReader { geometry in
            WebView { webView in
                self.webView = webView
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .id(item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onAppear {
                webViewHelper.canGoBack = false
                webViewHelper.canGoForward = false
                webViewHelper.isLoading = false
                webViewHelper.title = ""
                webViewHelper.url = nil
                webViewHelper.webView = webView
                webViewHelper.item = item
                webViewHelper.setupObservations()
                if let urlRequest = webViewHelper.urlRequest {
                    webView.load(urlRequest)
                }
            }
            .onChange(of: webViewHelper.urlRequest) { oldValue, newValue in
                if newValue != oldValue, let urlRequest = webViewHelper.urlRequest {
                    webViewHelper.webView?.load(urlRequest)
                }
            }
        }
    }

}
