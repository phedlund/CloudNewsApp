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
    @Environment(\.managedObjectContext) private var moc
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
        self._selection = State(initialValue: item.objectID)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(items, id: \.objectID) { item in
                ArticleView(item: item)
                    .tag(item.objectID)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
//            markItemRead()
//            if let item = moc.object(with: item.objectID) as? Item {
//                webViewHelper = item.webViewHelper
//            }
        }
        .onChange(of: selection) {
            markItemRead()
//            if let item = moc.object(with: $0) as? Item {
//                webViewHelper = item.webViewHelper
//            }
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
//            if let item = NewsData.shared.viewContext?.object(with: selection) as? Item {
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
