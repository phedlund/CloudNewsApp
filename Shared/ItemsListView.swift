//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Kingfisher
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
    @Environment(\.favIconRepository) private var favIconRepository
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.selectedNode) private var selectedNode: Node.ID?

    @Query private var items: [Item]

    @State private var cellHeight: CGFloat = .defaultCellHeight

    @State private var itemSelection: PersistentIdentifier?

    private let offsetDetector = ItemsOffsetDetector()

    init(predicate: Predicate<Item>, sort: SortDescriptor<Item>) {
        _items = Query(filter: predicate, sort: [sort])
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
                ScrollViewReader { proxy in
                    let indexedQuery = items.enumerated().map({ $0 })
                    List(indexedQuery, id: \.element.id, selection: $itemSelection) { index, item in
                        ZStackGroup(item: item) {
                            RowContainer {
                                ItemRow(item: item, itemImageManager: ItemImageManager(item: item), isHorizontalCompact: isHorizontalCompact, isCompact: compactView, size: cellSize)
                                    .id(index)
                                    .tag(item.persistentModelID)
                                    .environment(favIconRepository)
#if os(macOS)
                                    .frame(height: cellHeight, alignment: .center)
#endif
                                    .contextMenu {
                                        ContextMenuContent(item: item)
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
                                offsetDetector.offset = offset
                            }
                        }
                        .id(index)
                        .listRowSeparator(listRowSeparatorVisibility)
                        .listRowBackground(listRowBackground)
                    }
                    .onChange(of: selectedNode) { oldValue, newValue in
                        if newValue != oldValue {
                            proxy.scrollTo(0, anchor: .top)
                            offsetDetector.offset = 0.0
                        }
                    }
                }
                .newsNavigationDestination(type: Item.self, items: items)
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
                .onChange(of: offsetDetector.offset) { _, newValue in
                    Task.detached {
                        await markRead(newValue)
                    }
                }
#if !os(macOS)
                .onChange(of: horizontalSizeClass) { _, newValue in
                    isHorizontalCompact = newValue == .compact
                }
#endif
            }
        }
    }

    @MainActor
    private func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            Task(priority: .userInitiated) {
                let numberOfItems = max((offset / (cellHeight + cellSpacing)) - 1, 0)
                if numberOfItems > 0, let container = NewsData.shared.container {
                    let context = ModelContext(container)
                    let itemsToMarkRead = items.prefix(through: Int(numberOfItems)).filter( { $0.unread })
                    for item in itemsToMarkRead {
                        item.unread = false
                    }
                    try context.save()
                    if !itemsToMarkRead.isEmpty {
                        try? await NewsManager.shared.markRead(items: itemsToMarkRead, unread: false)
                    }
                }
            }
        }
    }

}

struct NavigationDestinationModifier: ViewModifier {
    let type: Item.Type
    let items: [Item]

    @ViewBuilder func body(content: Content) -> some View {
#if os(iOS)
        content
            .navigationDestination(for: type) { item in
                ArticlesPageView(item: item, items: items)
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
