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
    @Environment(FeedModel.self) private var feedModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Node.ID?

    @Query private var items: [Item]

    @State private var scrollToTop = false
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var itemSelection: PersistentIdentifier?
    @State private var lastOffset: CGFloat = .zero
    @State private var isScrollingToTop = false

    @Binding var selectedItem: Item?

    init(predicate: Predicate<Item>, sort: SortDescriptor<Item>, selectedItem: Binding<Item?>) {
        let fetchDescriptor = FetchDescriptor<Item>(predicate: predicate, sortBy: [sort])
        _items = Query(fetchDescriptor)
        self._selectedItem = selectedItem
    }

    var body: some View {
        //        let _ = Self._printChanges()
        GeometryReader { geometry in
#if os(macOS)
            let cellWidth = CGFloat.infinity
#else
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
#endif
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            ListGroup {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        ScrollToTopView(reader: proxy, scrollOnChange: $scrollToTop)
                        LazyVStack(alignment: .center, spacing: 16.0) {
                            ForEach(items, id: \.id) { item in
                                NavigationLink(value: item) {
                                    ItemView(item: item, size: cellSize)
#if os(macOS)
                                        .frame(height: cellHeight, alignment: .center)
                                        .onTapGesture {
                                            selectedItem = item
                                        }
#endif
                                        .contextMenu {
                                            contextMenu(item: item)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .navigationDestination(for: Item.self) {
#if !os(macOS)
                            ArticlesPageView(item: $0, items: items)
                                .environment(feedModel)
#endif
                        }
                        .scrollTargetLayout(isEnabled: true)
                        .onChange(of: selectedNode) { _, _ in
                            DispatchQueue.main.async {
                                isScrollingToTop = true
                                scrollToTop.toggle()
                                lastOffset = .zero
                                isScrollingToTop = false
                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                DispatchQueue.main.async {
                                    isScrollingToTop = true
                                    scrollToTop.toggle()
                                    lastOffset = .zero
                                    isScrollingToTop = false
                                }
                            }
                        }
                        .onChange(of: feedModel.isSyncing) { _, newValue in
                            if newValue == false {
                                DispatchQueue.main.async {
                                    isScrollingToTop = true
                                    scrollToTop.toggle()
                                    lastOffset = .zero
                                    isScrollingToTop = false
                                }
                            }
                        }
                        .onChange(of: $compactView.wrappedValue, initial: true) { _, newValue in
                            cellHeight = newValue ? .compactCellHeight : .defaultCellHeight
                        }
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .onScrollPhaseChange { _, newPhase, context in
                        if newPhase == .decelerating || newPhase == .idle {
                            Task {
                                try? await markRead(context.geometry.contentOffset.y)
                            }
                        }
                    }
                    .defaultScrollAnchor(.top)
                    .environment(feedModel)
                    .accentColor(.phDarkIcon)
                    .background {
                        Color.phWhiteBackground
                            .ignoresSafeArea(edges: .vertical)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(item: Item) -> some View {
        Button {
            feedModel.toggleItemRead(item: item)
        } label: {
            Label {
                Text(item.unread ? "Read" : "Unread")
            } icon: {
                Image(systemName: item.unread ? "eye" : "eye.slash")
            }
        }
        Button {
            Task {
                try? await feedModel.markStarred(item: item, starred: !item.starred)
            }
        } label: {
            Label {
                Text(item.starred ? "Unstar" : "Star")
            } icon: {
                Image(systemName: item.starred ? "star" : "star.fill")
            }
        }
    }
    
    @MainActor
    private func markRead(_ offset: CGFloat) async throws {
        guard feedModel.isSyncing == false, isScrollingToTop == false, scenePhase == .active, offset > lastOffset else {
            return
        }
        if markReadWhileScrolling {
            let numberOfItems = max((offset / (cellHeight + cellSpacing)) - 1, 0)
            if numberOfItems > 0 {
                let itemsToMarkRead = items
                    .prefix(through: Int(numberOfItems))
                    .filter( { $0.unread })
                feedModel.markItemsRead(items: itemsToMarkRead)
            }
        }
        lastOffset = offset
    }

}

struct NavigationDestinationModifier: ViewModifier {
    @Environment(FeedModel.self) private var feedModel
    let type: Item.Type
    let items: [Item]

    @ViewBuilder func body(content: Content) -> some View {
#if os(iOS)
        content
            .navigationDestination(for: type) { item in
                ArticlesPageView(item: item, items: items)
                    .environment(feedModel)
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
                withAnimation {
                    reader.scrollTo(topScrollPoint, anchor: .top)
                }
            }
    }
}
