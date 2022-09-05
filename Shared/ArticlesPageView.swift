//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI

#if os(iOS)
struct ArticlesPageView: View {
    @EnvironmentObject private var settings: Preferences
    @ObservedObject private var node: Node
    @ObservedObject private var model: ArticleModel
    @State private var selection: ArticleModel.ID
    @State private var isShowingPopover = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var title = ""
    @State private var webViewHelper = ItemWebViewHelper()

    init(item: ArticleModel, node: Node) {
        self.model = item
        self.node = node
        self._selection = State(initialValue: item.id)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(node.items, id: \.id) { item in
                ArticleView(item: item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
            markItemRead()
            if let item = node.item(for: selection) {
                webViewHelper = item.webViewHelper
            }
        }
        .onChange(of: selection) { _ in
            markItemRead()
            if let item = node.item(for: selection) {
                webViewHelper = item.webViewHelper
            }
        }
        .onReceive(webViewHelper.$canGoBack) {
            canGoBack = $0
        }
        .onReceive(webViewHelper.$canGoForward) {
            canGoForward = $0
        }
        .onReceive(webViewHelper.$isLoading) {
            isLoading = $0
        }
        .onReceive(webViewHelper.$title) {
            if $0 != title {
                title = $0
            }
        }
        .toolbar {
            pageViewToolBarContent()
        }
    }

    @ToolbarContentBuilder
    func pageViewToolBarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button {
                webViewHelper.webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!canGoBack)
            Button {
                webViewHelper.webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!canGoForward)
            Button {
                if isLoading {
                    webViewHelper.webView?.stopLoading()
                } else {
                    webViewHelper.webView?.reload()
                }
            } label: {
                if isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let item = node.item(for: selection) {
                let subject = item.title
                let message = item.displayBody
                if let url = webViewHelper.url {
                    if url.scheme?.hasPrefix("file") ?? false {
                        if let urlString = item.item.url, let itemUrl = URL(string: urlString) {
                            ShareLink(item: itemUrl, subject: Text(subject), message: Text(message))
                                .disabled(isLoading)
                        }
                    } else {
                        ShareLink(item: url, subject: Text(subject), message: Text(message))
                            .disabled(isLoading)
                    }
                } else if !subject.isEmpty {
                    ShareLink(item: subject, subject: Text(subject), message: Text(message))
                        .disabled(isLoading)
                }
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                if let item = node.item(for: selection)?.item {
                    ArticleSettingsView(item: item)
                        .environmentObject(settings)
                        .presentationDetents([.height(300.0)])
                }
            }
            .disabled(isLoading)
        }
    }
    private func markItemRead() {
        if let item = node.item(for: selection)?.item, item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
#endif
