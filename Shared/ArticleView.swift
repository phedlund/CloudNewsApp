//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    var item: ArticleModel

    var body: some View {
        WebView { webView in
            item.webViewHelper.model = item
            item.webViewHelper.webView = webView
            if let urlRequest = item.webViewHelper.urlRequest {
                webView.load(urlRequest)
            }
        }
        .id(item.id) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
    }
    
}

#if os(iOS)
extension UINavigationController {

  open override func viewWillLayoutSubviews() {
    navigationBar.topItem?.backButtonDisplayMode = .minimal
  }

}
#endif
