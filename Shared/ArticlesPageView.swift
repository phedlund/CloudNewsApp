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

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
        self._selection = State(initialValue: item.persistentModelID)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items, id: \.persistentModelID) { item in
                ArticleView(item: item)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(item.webViewHelper.title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
            markItemRead()
        }
        .onChange(of: selection) { _, newValue in
            markItemRead()
        }
        .toolbar(content: pageViewToolBarContent)
        .toolbarRole(.editor)
    }

    @ToolbarContentBuilder
    func pageViewToolBarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button {
                item.webViewHelper.webView?.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!item.webViewHelper.canGoBack)
            Button {
                item.webViewHelper.webView?.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!item.webViewHelper.canGoForward)
            Button {
                if item.webViewHelper.isLoading {
                    item.webViewHelper.webView?.stopLoading()
                } else {
                    item.webViewHelper.webView?.reload()
                }
            } label: {
                if item.webViewHelper.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let currentItem = items.first(where: { $0.persistentModelID == selection }) {
                ShareLinkButton(item: currentItem)
                    .disabled(item.webViewHelper.isLoading)
            } else {
                EmptyView()
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(item.webViewHelper.isLoading)
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
            item = currentItem
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
