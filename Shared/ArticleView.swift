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
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    private let content: ArticleWebContent

    init(content: ArticleWebContent) {
        self.content = content
    }

    var body: some View {
        WebView(content.page)
            .webViewBackForwardNavigationGestures(.disabled)
            .scrollIndicators(.visible, axes: .vertical)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding([.top], 40)
            .onChange(of: fontSize) {
                content.reloadItemSummary(true)
            }
            .onChange(of: lineHeight) {
                content.reloadItemSummary(true)
            }
            .onChange(of: marginPortrait) {
                content.reloadItemSummary(true)
            }
    }

}
#endif

