//
//  PagerWrapper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/24/22.
//

#if os(macOS)
import SwiftUI

struct MacArticleView: View {
    @ObservedObject var articleModel: ArticleModel

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false

    var body: some View {
        ArticleWebView(model: articleModel)
            .navigationTitle(title)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onAppear {
                markItemRead()
            }
            .onReceive(articleModel.$canGoBack) {
                canGoBack = $0
            }
            .onReceive(articleModel.$canGoForward) {
                canGoForward = $0
            }
            .onReceive(articleModel.$isLoading) {
                isLoading = $0
            }
            .onReceive(articleModel.$title) {
                if $0 != title {
                    title = $0
                }
            }
            .toolbar(content: articleToolBarContent)
    }

    @ToolbarContentBuilder
    func articleToolBarContent() -> some ToolbarContent {
            ToolbarItemGroup {
                Button {
                    articleModel.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!canGoBack)
                Button {
                    articleModel.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!canGoForward)
                Button {
                    if isLoading {
                        articleModel.webView.stopLoading()
                    } else {
                        articleModel.webView.reload()
                    }
                } label: {
                    if isLoading {
                        Image(systemName: "xmark")
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Spacer()
                ShareLinkView(model: articleModel)
                .disabled(isLoading)
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    if let item = articleModel.item {
                        ArticleSettingsView(item: item)
                    }
                }
                .disabled(isLoading)
            }
    }

    private func markItemRead() {
        if let item = articleModel.item, item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

}
#endif
