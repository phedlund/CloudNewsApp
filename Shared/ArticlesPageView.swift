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
    @State private var currentPage = WebPage()
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
        .navigationTitle(currentPage.title)
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
        .onChange(of: pageViewProxy.itemId ?? 0, initial: true) { _, _ in
            currentPage = pageViewProxy.page
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
                print("Tapping Back for \(currentPage.title)")
                currentPage.load(currentPage.backForwardList.backList.last!)
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(currentPage.backForwardList.backList.isEmpty)
            Button {
                print("Tapping Forward for \(currentPage.title)")
                currentPage.load(currentPage.backForwardList.forwardList.last!)
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(currentPage.backForwardList.forwardList.isEmpty)
            Button {
                if currentPage.isLoading {
                    currentPage.stopLoading()
                } else {
                    currentPage.reload()
                }
            } label: {
                if currentPage.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let currentItem = items.first(where: { $0.id == pageViewProxy.scrollId }) {
                ShareLinkButton(item: currentItem, url: currentPage.url)
                    .disabled(currentPage.isLoading)
            } else {
                EmptyView()
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(currentPage.isLoading || currentPage.url?.scheme != "file")
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
