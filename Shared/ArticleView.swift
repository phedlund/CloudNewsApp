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

    var body: some View {
        GeometryReader { geometry in
            WebView { webView in
                webViewHelper.item = item
                webViewHelper.webView = webView
                webViewHelper.setupObservations()
                if let urlRequest = webViewHelper.urlRequest {
                    webView.load(urlRequest)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .id(item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onChange(of: webViewHelper.urlRequest) { oldValue, newValue in
                if newValue != oldValue, let urlRequest = webViewHelper.urlRequest {
                    webViewHelper.webView?.load(urlRequest)
                }
            }
        }
    }

}
