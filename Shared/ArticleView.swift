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
        GeometryReader { geometry in
            WebView { webView in
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
            .task {
                if let request = item.webViewHelper.urlRequest {
                    item.webViewHelper.webView?.load(request)
                }
                item.unread = false
                do {
                    try NewsData.shared.container?.mainContext.save()
                } catch {
                    //
                }
                Task {
                    try? await NewsManager.shared.markRead(items: [item], unread: false)
                }
            }
        }
    }

}
