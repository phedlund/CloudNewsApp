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
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @State private var item: Item
    @State private var scrollId: Int64?
    @State private var isShowingPopover = false

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    ArticleView(item: item)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .onChange(of: fontSize) {
                            item.webViewHelper.webView?.reload()
                        }
                        .onChange(of: lineHeight) {
                            item.webViewHelper.webView?.reload()
                        }
                        .onChange(of: marginPortrait) {
                            item.webViewHelper.webView?.reload()
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $scrollId, anchor: .center)
        .scrollTargetBehavior(.paging)
        .navigationTitle(item.webViewHelper.title)
        .scrollContentBackground(.hidden)
        .background {
            Color.pbh.whiteBackground
                .ignoresSafeArea(edges: .vertical)
        }
        .toolbar(content: pageViewToolBarContent)
        .toolbarRole(.editor)
        .onAppear {
            scrollId = item.id
        }
        .onChange(of: scrollId, initial: true) { _, newValue in
            if let newItem = items.first(where: { $0.id == newValue } ), newItem.unread {
                feedModel.markItemsRead(items: [newItem])
            }
        }
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
            if let currentItem = items.first(where: { $0.id == scrollId }) {
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
                if let currentItem = items.first(where: { $0.id == scrollId }) {
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
