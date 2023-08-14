//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftData
import SwiftUI

#if os(iOS)
struct ArticlesPageView: View {
    @Environment(\.feedModel) private var feedModel

    @State private var item: Item
    @State private var selection: PersistentIdentifier
    @State private var isShowingPopover = false
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var title = ""
    @State private var webViewHelper = ItemWebViewHelper()

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
        self._selection = State(initialValue: item.persistentModelID)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items, id: \.persistentModelID) { item in
                ArticleView(item: item, webViewHelper: $webViewHelper)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
            markItemRead()
        }
        .onChange(of: selection) { _, newValue in
            markItemRead()
        }
        .onChange(of: webViewHelper.canGoBack) { _, newValue in
            canGoBack = newValue
        }
        .onChange(of: webViewHelper.canGoForward) { _, newValue in
            canGoForward = newValue
        }
        .onChange(of: webViewHelper.isLoading) { _, newValue in
            isLoading = newValue
        }
        .onChange(of: webViewHelper.title) { _, newValue in
            if newValue != title {
                title = newValue
            }
        }
        .toolbar(content: pageViewToolBarContent)
        .toolbarRole(.editor)
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
            if let currentItem = items.first(where: { $0.persistentModelID == selection }) {
                ShareLinkButton(item: currentItem)
                    .disabled(isLoading)
            } else {
                EmptyView()
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(isLoading)
            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                if let currentItem = items.first(where: { $0.persistentModelID == selection }) {
                    ArticleSettingsView(item: currentItem)
                        .presentationDetents([.height(300.0)])
                }
            }
        }
    }

    private func markItemRead() {
        if let currentItem = items.first(where: { $0.persistentModelID == selection }) {
            Task {
                try? await NewsManager.shared.markRead(items: [currentItem], unread: false)
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
