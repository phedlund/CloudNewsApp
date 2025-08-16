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
    private let webContent: ArticleWebContent

    init(webContent: ArticleWebContent) {
        self.webContent = webContent
        self.webContent.reloadItemSummary()
    }

    var body: some View {
        WebView(webContent.page)
            .webViewBackForwardNavigationGestures(.disabled)
            .scrollIndicators(.visible, axes: .vertical)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding([.top], 40)
    }

}
#endif

