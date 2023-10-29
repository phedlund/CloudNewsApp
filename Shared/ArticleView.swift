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

    @State private var webView = WKWebView()

    var body: some View {
        GeometryReader { geometry in
            WebView { webView in
                self.webView = webView
                item.webViewHelper.updateItem(item: item)
                item.webViewHelper.webView = webView
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .id(item.persistentModelID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onChange(of: item.webViewHelper.urlRequest) { oldValue, newValue in
                if newValue != oldValue, let urlRequest = item.webViewHelper.urlRequest {
                    item.webViewHelper.webView?.load(urlRequest)
                }
            }
        }
    }

}
