//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
import SwiftData
import SwiftUI

struct ItemsListView: View {
#if os(macOS)
    let cellSpacing: CGFloat = 15.0
    let listRowSeparatorVisibility: Visibility = .visible
    let listRowBackground = EmptyView()
#else
    @State private var isHorizontalCompact = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let cellSpacing: CGFloat = 21.0
    let listRowSeparatorVisibility: Visibility = .hidden
    let listRowBackground = Color.phWhiteBackground
#endif
    @Environment(NewsModel.self) private var newsModel
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?

    @Query private var items: [Item]

    @State private var path = [Item]()
    @State private var scrollToTop = false
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var lastOffset: CGFloat = .zero
    @State private var isScrollingToTop = false
    @State private var sortDescriptors: [SortDescriptor<Item>]

    @Binding var selectedItem: Item?

    let fetchDescriptor: FetchDescriptor<Item>

    init(fetchDescriptor: FetchDescriptor<Item>, selectedItem: Binding<Item?>) {
        self._selectedItem = selectedItem
        sortDescriptors = fetchDescriptor.sortBy
        self.fetchDescriptor = fetchDescriptor
        _items = Query(fetchDescriptor)
    }

    var body: some View {
        let _ = Self._printChanges()
        GeometryReader { geometry in
#if os(macOS)
            let cellWidth = CGFloat.infinity
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            List(items, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    ItemView(item: item, size: cellSize)
                        .id(item.id)
                        .frame(height: cellHeight, alignment: .center)
                        .contextMenu {
                            contextMenu(item: item)
                        }
                }
            }
#else
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            ListGroup(path: $path) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        ScrollToTopView(reader: proxy, scrollOnChange: $scrollToTop)
                        LazyVStack(alignment: .center, spacing: 16.0) {
                            ForEach(items, id: \.id) { item in
                                NavigationLink(value: item) {
                                    ItemView(item: item, size: cellSize)
                                        .id(item.id)
                                        .contextMenu {
                                            contextMenu(item: item)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .newsNavigationDestination(type: Item.self, items: items)
                        .onChange(of: selectedNode) { _, _ in
                            path.removeAll()
                            doScrollToTop()
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                doScrollToTop()
                            }
                        }
                        .onChange(of: syncManager.syncManagerReader.isSyncing) { _, newValue in
                            if newValue == false {
                                doScrollToTop()
                            }
                        }
                        .onChange(of: $compactView.wrappedValue, initial: true) { _, newValue in
                            cellHeight = newValue ? .compactCellHeight : .defaultCellHeight
                        }
                    }
                    .onScrollPhaseChange { _, newPhase, context in
                        if newPhase == .idle {
                            Task {
                                try? markRead(context.geometry.contentOffset.y)
                            }
                        }
                    }
                    .defaultScrollAnchor(.top)
                    .accentColor(.phDarkIcon)
                    .background {
                        Color.phWhiteBackground
                            .ignoresSafeArea(edges: .vertical)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
#endif
        }
    }

    @MainActor
    func doScrollToTop() {
        isScrollingToTop = true
        scrollToTop.toggle()
        lastOffset = .zero
        isScrollingToTop = false
    }

    @ViewBuilder
    private func contextMenu(item: Item) -> some View {
        Button {
            newsModel.toggleItemRead(item: item)
        } label: {
            Label {
                Text(item.unread ? "Read" : "Unread")
            } icon: {
                Image(systemName: item.unread ? "eye" : "eye.slash")
            }
        }
        Button {
            Task {
                try? await newsModel.markStarred(item: item, starred: !item.starred)
            }
        } label: {
            Label {
                Text(item.starred ? "Unstar" : "Star")
            } icon: {
                Image(systemName: item.starred ? "star" : "star.fill")
            }
        }
    }

    private func markRead(_ offset: CGFloat) throws {
        guard isScrollingToTop == false, scenePhase == .active, offset > lastOffset else {
            return
        }
        if markReadWhileScrolling {
            let numberOfItems = Int(max((offset / (cellHeight + cellSpacing)) - 1, 0))
            if numberOfItems > 0 {
                let itemsToMarkRead = try modelContext.fetch(fetchDescriptor)
                    .prefix(numberOfItems)
                    .filter( { $0.unread == true } )
                newsModel.markItemsRead(items: Array(itemsToMarkRead))
            }
        }
        lastOffset = offset
    }

}

struct NavigationDestinationModifier: ViewModifier {
    @Environment(NewsModel.self) private var newsModel
    let type: Item.Type
    let items: [Item]

    @ViewBuilder func body(content: Content) -> some View {
#if os(iOS)
        content
            .navigationDestination(for: type) { item in
                ArticlesPageView(item: item, items: items)
                    .environment(newsModel)
            }
#else
        content
#endif
    }
}

extension View {
    func newsNavigationDestination(type: Item.Type, items: [Item]) -> some View {
        modifier(NavigationDestinationModifier(type: Item.self, items: items))
    }
}

struct ScrollToTopView: View {
    private let topScrollPoint = "topScrollPoint"
    let reader: ScrollViewProxy
    @Binding var scrollOnChange: Bool

    var body: some View {
        EmptyView()
            .id(topScrollPoint)
            .onChange(of: scrollOnChange) { _, _ in
                reader.scrollTo(topScrollPoint, anchor: .top)
            }
    }
}
