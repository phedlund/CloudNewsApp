//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftData
import SwiftUI
import WebKit

#if os(iOS)
struct ArticlesPageView: View {
    @Environment(NewsModel.self) private var newsModel

    @State private var item: Item
    @State private var itemsToMarkRead = [Item]()
    @State private var isAppearing = false
    @State private var isShowingPopover = false
    @Bindable var pageViewProxy = PageViewProxy(page: WebPage())

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    ArticleView(content: ArticleWebContent(item: item), pageViewReader: pageViewProxy)
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .navigationTitle(pageViewProxy.page.title)
        .scrollContentBackground(.hidden)
        .background {
            Color.phWhiteBackground
                .ignoresSafeArea(edges: .vertical)
        }
        .toolbar {
            pageViewToolBarContent(pageViewProxy: pageViewProxy)
        }
        .toolbarRole(.editor)
//        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .onAppear {
            pageViewProxy.scrollId = item.id
            isAppearing = true
        }
        .onChange(of: pageViewProxy.scrollId ?? 0, initial: false) { _, newValue in
            if let newItem = items.first(where: { $0.id == newValue } ), newItem.unread {
                if isAppearing {
                    newsModel.markItemsRead(items: [newItem])
                    isAppearing = false
                } else {
                    itemsToMarkRead.append(newItem)
                }
            }
        }
        .onScrollPhaseChange { _, newPhase in
            if  newPhase == .idle {
                newsModel.markItemsRead(items: itemsToMarkRead)
                itemsToMarkRead.removeAll()
            }
        }
        .scrollPosition(id: $pageViewProxy.scrollId)
    }

    @ToolbarContentBuilder
    func pageViewToolBarContent(pageViewProxy: PageViewProxy) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                print("Tapping Back for \(pageViewProxy.page.title)")
                pageViewProxy.page.load(URLRequest(url: pageViewProxy.page.backForwardList.backList.last!.url))
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(pageViewProxy.page.backForwardList.backList.isEmpty)
            Button {
                print("Tapping Forward for \(pageViewProxy.page.title)")
                pageViewProxy.page.load(URLRequest(url: pageViewProxy.page.backForwardList.forwardList.last!.url))
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(pageViewProxy.page.backForwardList.forwardList.isEmpty)
            Button {
                if pageViewProxy.page.isLoading {
                    pageViewProxy.page.stopLoading()
                } else {
                    pageViewProxy.page.reload()
                }
            } label: {
                if pageViewProxy.page.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let currentItem = items.first(where: { $0.id == pageViewProxy.scrollId }) {
                ShareLinkButton(item: currentItem, url: pageViewProxy.page.url)
                    .disabled(pageViewProxy.page.isLoading)
            } else {
                EmptyView()
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(pageViewProxy.page.isLoading || pageViewProxy.page.url?.scheme != "file")
            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                if let currentItem = items.first(where: { $0.id == pageViewProxy.scrollId }) {
                    ArticleSettingsView(item: currentItem)
                        .presentationDetents([.height(300.0)])
                }
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
