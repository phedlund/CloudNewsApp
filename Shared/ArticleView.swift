//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

#if !os(macOS)
import SwiftUI
import WebKit

struct ArticleView: View {
    private let page: WebPage

    init(page: WebPage) {
        self.page = page
    }

    var body: some View {
        WebView(page)
            .webViewBackForwardNavigationGestures(.disabled)
            .scrollIndicators(.visible, axes: .vertical)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding([.top], 40)
    }

}
#endif

