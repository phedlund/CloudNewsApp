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
    @Environment(FeedModel.self) private var feedModel
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    @State private var item: Item
    @State private var scrollId: Int64?
    @State private var isShowingPopover = false
    @State private var pageViewProxy = PageViewProxy()

    private let items: [Item]

    init(item: Item, items: [Item]) {
        self.items = items
        self._item = State(initialValue: item)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items, id: \.id) { item in
                    ArticleView(item: item, pageViewReader: pageViewProxy)
                        .containerRelativeFrame([.horizontal, .vertical])
//                        .onChange(of: fontSize) {
//                            item.webViewHelper.webView?.reload()
//                        }
//                        .onChange(of: lineHeight) {
//                            item.webViewHelper.webView?.reload()
//                        }
//                        .onChange(of: marginPortrait) {
//                            item.webViewHelper.webView?.reload()
//                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrollId)
        .navigationTitle(pageViewProxy.title)
        .scrollContentBackground(.hidden)
        .background {
            Color.phWhiteBackground
                .ignoresSafeArea(edges: .vertical)
        }
        .toolbar {
            pageViewToolBarContent(pageViewProxy: pageViewProxy)
        }
        .toolbarRole(.editor)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .onAppear {
            scrollId = item.id
        }
        .onChange(of: scrollId ?? 0, initial: true) { _, newValue in
            pageViewProxy.scrollId = newValue
            print(newValue)
            if let newItem = items.first(where: { $0.id == newValue } ), newItem.unread {
                feedModel.markItemsRead(items: [newItem])
            }
        }
    }

    @ToolbarContentBuilder
    func pageViewToolBarContent(pageViewProxy: PageViewProxy) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                pageViewProxy.goBack = true
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!pageViewProxy.canGoBack)
            Button {
                pageViewProxy.goForward = true
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!pageViewProxy.canGoForward)
            Button {
                if pageViewProxy.isLoading {
                    pageViewProxy.reload = false
                } else {
                    pageViewProxy.reload = true
                }
            } label: {
                if pageViewProxy.isLoading {
                    Image(systemName: "xmark")
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if let currentItem = items.first(where: { $0.id == scrollId }) {
                ShareLinkButton(item: currentItem)
                    .disabled(pageViewProxy.isLoading)
            } else {
                EmptyView()
            }
            Button {
                isShowingPopover = true
            } label: {
                Image(systemName: "textformat.size")
            }
            .disabled(pageViewProxy.isLoading)
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
