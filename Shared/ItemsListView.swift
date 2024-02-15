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
    @State private var isHorizontalCompact = false
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

    @Namespace private var topId

    @Query private var items: [Item]

    @State private var cellHeight: CGFloat = .defaultCellHeight

    @State private var itemSelection: PersistentIdentifier?
    @State private var scrollId: Int64?

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>

    init(predicate: Predicate<Item>, sort: SortDescriptor<Item>) {
        var fetchDescriptor = FetchDescriptor<Item>(predicate: predicate, sortBy: [sort])
//        fetchDescriptor.fetchLimit = 20

        _items = Query(fetchDescriptor)
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    var body: some View {
        let _ = Self._printChanges()
        GeometryReader { geometry in
#if os(macOS)
            let cellWidth = CGFloat.infinity
#else
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
#endif
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            ListGroup {
                ScrollView(.vertical) {
                    ScrollViewReader { proxy in
                        Group { }
                            .id(topId)
                        LazyVStack(alignment: .center, spacing: 16.0) {
                            ForEach(items, id: \.id) { item in
                                ItemView(item: item, size: cellSize)
                                //                                    .id(item.persistent)
//                                                                    .id(item.persistentModelID)
#if os(macOS)
                                    .frame(height: cellHeight, alignment: .center)
#endif
                                    .contextMenu {
                                        ContextMenuContent(item: item)
                                            .environment(feedModel)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                        .onChange(of: scrollId) { oldValue, newValue in
                            print("Scroll ID \(newValue ?? 0)")
                        }
                        .onChange(of: selectedNode) { oldValue, newValue in
                            scrollId = items.first?.id
//                            if newValue != oldValue {
//                                proxy.scrollTo(topId, anchor: .top)
//                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                scrollId = items.first?.id
//                                proxy.scrollTo(topId, anchor: .top)
                            }
                        }
                    }
                    //                    .defaultScrollAnchor(.top)
                    .newsNavigationDestination(type: Item.self, items: items)
                }
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

    @MainActor
    private func markRead(_ offset: CGFloat) async throws {
        if markReadWhileScrolling {
            let numberOfItems = max((offset / (cellHeight + cellSpacing)) - 1, 0)
            if numberOfItems > 0 {
                let itemsToMarkRead = items.prefix(through: Int(numberOfItems)).filter( { $0.unread })
                feedModel.markItemsRead(items: itemsToMarkRead)
            }
        }
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
