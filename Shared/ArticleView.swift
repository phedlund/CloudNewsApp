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

    var body: some View {
        WebView { webView in
            item.webViewHelper.updateItem(item: item)
            item.webViewHelper.webView = webView
        }
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
        .task {
            if let request = item.webViewHelper.urlRequest {
                item.webViewHelper.webView?.load(request)
            }
        }
    }

}
