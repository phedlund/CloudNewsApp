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
    let listRowBackground = Color.pbh.whiteBackground
#endif
    @Environment(\.feedModel) private var feedModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.selectedNode) private var selectedNode: Node.ID?

    @Query private var items: [Item]

    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var itemSelection: PersistentIdentifier?
    @State private var scrollId: Int64?
    @State private var lastOffset: CGFloat = 0.0

    private let coordinateSpaceName = "scrollingEnded"

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
                ScrollView(.vertical) {
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
                                        ContextMenuContent(item: item)
                                            .environment(feedModel)
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
                    .onScrollEnded(in: .named(coordinateSpaceName), onScrollEnded: updateScrollPosition(_:))
                    .scrollTargetLayout()
                    .onChange(of: selectedNode) { _, _ in
                        DispatchQueue.main.async {
                            scrollId = items.first?.id
                            lastOffset = 0.0
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            DispatchQueue.main.async {
                                scrollId = items.first?.id
                                lastOffset = 0.0
                            }
                        }
                    }
                    .onChange(of: $compactView.wrappedValue, initial: true) { _, newValue in
                        cellHeight = newValue ? .compactCellHeight : .defaultCellHeight
                    }
                }
                .coordinateSpace(name: coordinateSpaceName)
                .defaultScrollAnchor(.top)
                .scrollPosition(id: $scrollId)
                .environment(feedModel)
                .accentColor(.pbh.darkIcon)
                .background {
                    Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                }
                .scrollContentBackground(.hidden)
            }

            /*
             ScrollViewReader { proxy in
             let indexedQuery = items.enumerated().map({ $0 })
             List(indexedQuery, id: \.element.id, selection: $itemSelection) { index, item in
             ZStackGroup(item: item) {
             RowContainer {
             ItemView(item: item, size: cellSize)
             .id(index)
             .tag(item.persistentModelID)
             .environment(favIconRepository)
             #if os(macOS)
             .frame(height: cellHeight, alignment: .center)
             #endif
             .contextMenu {
             ContextMenuContent(item: item)
             .environment(feedModel)
             }
             .alignmentGuide(.listRowSeparatorLeading) { _ in
             return 0
             }
             }
             .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
             prefKey = CGFloat(index)
             }
             .onPreferenceChange(ViewOffsetKey.self) {
             let offset = ($0 * (cellHeight + cellSpacing)) - geometry.size.height
             offsetItemsDetector.send(offset)
             }
             }
             .id(index)
             .listRowSeparator(listRowSeparatorVisibility)
             .listRowBackground(listRowBackground)
             }
             .onChange(of: selectedNode) { oldValue, newValue in
             if newValue != oldValue {
             proxy.scrollTo(0, anchor: .top)
             offsetItemsDetector.send(0.0)
             }
             }
             .onChange(of: scenePhase) { _, newPhase in
             if newPhase == .active {
             proxy.scrollTo(0, anchor: .top)
             }
             }
             }
             .newsNavigationDestination(type: Item.self, items: items)
             .environment(feedModel)
             .listStyle(.plain)
             .accentColor(.pbh.darkIcon)
             .background {
             Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
             }
             .scrollContentBackground(.hidden)
             .onAppear {
             #if !os(macOS)
             isHorizontalCompact = horizontalSizeClass == .compact
             #endif
             cellHeight = compactView ? .compactCellHeight : .defaultCellHeight
             }
             .onChange(of: $compactView.wrappedValue) { _, newValue in
             cellHeight = newValue ? .compactCellHeight : .defaultCellHeight
             }
             .onReceive(offsetItemsPublisher) { newOffset in
             Task.detached(priority: .background) {
             try await markRead(newOffset)
             }
             }
             #if !os(macOS)
             .onChange(of: horizontalSizeClass) { _, newValue in
             isHorizontalCompact = newValue == .compact
             }
             #endif
             */
        }
    }

    private func updateScrollPosition(_ position: CGFloat) {
        Task.detached {
            try await markRead(position)
        }
    }

    @MainActor
    private func markRead(_ offset: CGFloat) async throws {
        guard scenePhase == .active, offset > lastOffset else {
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
    @Environment(\.feedModel) private var feedModel
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
