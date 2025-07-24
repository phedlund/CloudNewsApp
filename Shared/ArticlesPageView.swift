//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import Foundation
import SwiftData
import SwiftUI
import WebKit

#if os(iOS)
struct ArticlesPageView: View {
    @Environment(NewsModel.self) private var newsModel

    @State private var itemsToMarkRead = [Item]()
    @State private var isShowingPopover = false
    @State private var currentPage = WebPage()
    @Bindable var pageViewProxy = PageViewProxy(page: WebPage())

    private let item: Item
    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self.item = item
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
            .onReceive(NotificationCenter.default.publisher(for: .previousArticle)) { notification in
                var nextIndex = items.startIndex
                if let selectedItemId = pageViewProxy.scrollId, let selectedItem = items.first(where: { $0.id == selectedItemId } ), let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: -1)
                }
                if nextIndex <= items.startIndex {
                    nextIndex = items.startIndex
                }
                let previousItem = items[nextIndex]
                pageViewProxy.scrollId = previousItem.id
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextArticle)) { notification in
                var nextIndex = items.startIndex
                if let selectedItemId = pageViewProxy.scrollId, let selectedItem = items.first(where: { $0.id == selectedItemId } ), let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: 1)
                }
                if nextIndex > items.endIndex {
                    nextIndex = items.startIndex
                }
                let nextItem = items[nextIndex]
                pageViewProxy.scrollId = nextItem.id
            }
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $pageViewProxy.scrollId)
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
        .task {
            pageViewProxy.scrollId = item.id
            if let newItem = items.first(where: { $0.id == item.id } ) {
                newsModel.currentItem = newItem
                if newItem.unread {
                    await newsModel.markItemsRead(items: [newItem])
                }
            }
        }
        .onChange(of: pageViewProxy.scrollId ?? 0, initial: false) { _, newValue in
            if let newItem = items.first(where: { $0.id == newValue } ) {
                newsModel.currentItem = newItem
                if newItem.unread {
                    itemsToMarkRead.append(newItem)
                }
            }
        }
        .onChange(of: pageViewProxy.itemId ?? 0, initial: true) { _, _ in
            currentPage = pageViewProxy.page
        }
        .onScrollPhaseChange { _, newPhase in
            if  newPhase == .idle {
                Task {
                    await newsModel.markItemsRead(items: itemsToMarkRead)
                    itemsToMarkRead.removeAll()
                }
            }
        }
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
            ShareLinkButton(item: newsModel.currentItem, url: currentPage.url)
                .disabled(currentPage.isLoading)
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(currentPage.isLoading)
            .disabled(currentPage.url?.scheme != "file")
            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                ArticleSettingsView()
                    .presentationDetents([.height(300.0)])
                    .environment(newsModel)
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
