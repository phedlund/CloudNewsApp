//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @Environment(\.feedModel) private var feedModel

    var item: Item

    let webViewHelper = ItemWebViewHelper()

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
//            .id(item.objectID) //forces the web view to be recreated to get a unique WKWebView for each article
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onAppear {
                feedModel.currentWebViewHelper = webViewHelper
            }
            .onChange(of: webViewHelper.content) { oldValue, newValue in
                if let url = newValue?.url {
//                    webViewHelper.webView?.reload()
                    webViewHelper.urlRequest = URLRequest(url: url)
                    if let urlRequest = webViewHelper.urlRequest {
                        webViewHelper.webView?.load(urlRequest)
                    }

                }
            }
        }
    }

//    func tracker() {
//        withObservationTracking({
//            webViewHelper.content
//        }, onChange: {
//            print("Content Changed")
//        })
//
//    }
}
