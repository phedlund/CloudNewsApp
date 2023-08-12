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
    @State private var webViewHelper: ItemWebViewHelper

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
        self._selection = State(initialValue: item.persistentModelID)
        self._webViewHelper = State(initialValue: ItemWebViewHelper())
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items, id: \.persistentModelID) { item in
                ArticleView(item: item)
                    .id(item.persistentModelID)
                    .environment(feedModel)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
            markItemRead()
            webViewHelper = feedModel.currentWebViewHelper
        }
        .onChange(of: selection) { _, newValue in
            markItemRead()
            webViewHelper = feedModel.currentWebViewHelper
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
//            if let item = NewsData.shared.container?.mainContext.object(with: item.objectID) as? Item {
//                ShareLinkButton(item: item)
//                    .disabled(isLoading)
//            } else {
                EmptyView()
//            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(isLoading)
            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
//                if let item = moc.object(with: selection) as? CDItem {
//                    ArticleSettingsView(item: item)
//                        .presentationDetents([.height(300.0)])
//                }
            }
        }
    }

    private func markItemRead() {
//        if let item = moc.object(with: selection) as? Item, item.unread {
//            Task {
//                // TODO try? await NewsManager.shared.markRead(items: [item], unread: false)
//            }
//        }
    }

}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
#endif
