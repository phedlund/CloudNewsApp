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
struct ArticlesPageViewModel {
    let items: [ArticleWebContent]
    init(itemModels: [Item], openUrlAction: OpenURLAction) {
        self.items = itemModels.map { item in
            ArticleWebContent(item: item, openUrlAction: openUrlAction)
        }
    }
}

struct ArticlesPageView: View {
    @Environment(NewsModel.self) private var newsModel
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @State private var itemsToMarkRead = [Item]()
    @State private var isShowingPopover = false
    @State private var currentPage = WebPage()
    @State private var scrollId: Int64?
    @State private var viewModel: ArticlesPageViewModel? = nil

    private let itemModels: [Item]
    private var isButtonDisabled: Bool {
        currentPage.isLoading || (currentPage.url != nil && currentPage.url?.scheme != "file")
    }

    init(itemId: Int64, items: [Item]) {
        self.itemModels = items
        _scrollId = .init(initialValue: itemId)
    }

    var body: some View {
        let items = viewModel?.items ?? []

        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    ArticleView(webContent: item)
                        .safeAreaPadding(.top, 50)
                        .safeAreaPadding(.bottom, 20)
                        .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
            .onReceive(NotificationCenter.default.publisher(for: .previousArticle)) { notification in
                var nextIndex = items.startIndex
                if let selectedItemId = scrollId, let selectedItem = items.first(where: { $0.id == selectedItemId } ), let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: -1)
                }
                if nextIndex <= items.startIndex {
                    nextIndex = items.startIndex
                }
                let previousItem = items[nextIndex]
                scrollId = previousItem.id
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextArticle)) { notification in
                var nextIndex = items.startIndex
                if let selectedItemId = scrollId, let selectedItem = items.first(where: { $0.id == selectedItemId } ), let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: 1)
                }
                if nextIndex > items.endIndex {
                    nextIndex = items.startIndex
                }
                let nextItem = items[nextIndex]
                scrollId = nextItem.id
            }
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrollId)
        .navigationTitle(currentPage.title)
        .scrollContentBackground(.hidden)
        .background {
            Color.phWhiteBackground
                .ignoresSafeArea(edges: .vertical)
        }
        .toolbar {
            pageViewToolBarContent()
        }
        .toolbarRole(.editor)
        .task {
            if viewModel == nil {
                viewModel = ArticlesPageViewModel(itemModels: itemModels, openUrlAction: openURL)
                if let newItem = viewModel?.items.first(where: { $0.id == scrollId } ) {
                    currentPage = newItem.page
                    newsModel.currentItem = newItem.item
                    if newItem.item.unread {
                        await newsModel.markItemsRead(items: [newItem.item])
                    }
                }
            }
        }
        .onChange(of: scrollId ?? 0, initial: false) { _, newValue in
            if let newItem = items.first(where: { $0.id == newValue } ) {
                currentPage = newItem.page
                newsModel.currentItem = newItem.item
                if newItem.item.unread {
                    itemsToMarkRead.append(newItem.item)
                }
            }
        }
        .onScrollPhaseChange { _, newPhase in
            if  newPhase == .idle {
                Task {
                    await newsModel.markItemsRead(items: itemsToMarkRead)
                    itemsToMarkRead.removeAll()
                }
            }
        }
        .onChange(of: fontSize) {
            if let newItem = items.first(where: { $0.id == scrollId } ) {
                newItem.reloadItemSummary(true)
            }
        }
        .onChange(of: lineHeight) {
            if let newItem = items.first(where: { $0.id == scrollId } ) {
                newItem.reloadItemSummary(true)
            }
        }
        .onChange(of: marginPortrait) {
            if let newItem = items.first(where: { $0.id == scrollId } ) {
                newItem.reloadItemSummary(true)
            }
        }
    }

    @ToolbarContentBuilder
    func pageViewToolBarContent() -> some ToolbarContent {
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
            .disabled(isButtonDisabled)
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

