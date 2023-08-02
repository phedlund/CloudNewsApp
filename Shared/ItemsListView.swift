//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
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
    @Environment(\.feedModel) private var feedModel
    @Environment(\.favIconRepository) private var favIconRepository
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.selectedNode) private var selectedNode = ""

    @State private var cellHeight: CGFloat = .defaultCellHeight

    @Binding var itemSelection: PersistentIdentifier?

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>

    init(itemSelection: Binding<PersistentIdentifier?>) {
        self._itemSelection = itemSelection
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
                ScrollViewReader { proxy in
                    List(feedModel.currentItems.indices, id: \.self, selection: $itemSelection) { index in
                        let item = feedModel.currentItems[index]
                        ZStackGroup(item: item) {
                            RowContainer {
                                ItemRow(item: item, itemImageManager: ItemImageManager(item: item), isHorizontalCompact: isHorizontalCompact, isCompact: compactView, size: cellSize)
                                    .id(index)
                                    .tag(item.objectID)
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
                                offsetItemsDetector.send(offset)
                            }
                        }
                        .listRowSeparator(listRowSeparatorVisibility)
                        .listRowBackground(listRowBackground)
                    }
                    .onChange(of: $selectedNode.wrappedValue) { oldValue, newValue in
                        if newValue != oldValue {
                            proxy.scrollTo(0, anchor: .top)
                            offsetItemsDetector.send(0.0)
                        }
                    }
                }
                .newsNavigationDestination(type: Item.self, model: feedModel)
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
                .onChange(of: $compactView.wrappedValue) {
                    cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                }
                .onChange(of: hideRead) { _ in
                    feedModel.updateVisibleItems()
                }
                .onChange(of: sortOldestFirst) { _ in
                    feedModel.updateItemSorting()
                }
                .onReceive(offsetItemsPublisher) { newOffset in
                    Task.detached {
                        await markRead(newOffset)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        feedModel.currentNodeID = selectedNode
                    default:
                        break
                    }
                }
#if !os(macOS)
                .onChange(of: horizontalSizeClass) {
                    isHorizontalCompact = $0 == .compact
                }
#endif
            }
        }
    }

    private func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            print(offset)
            let numberOfItems = max((offset / (cellHeight + cellSpacing)) - 1, 0)
            print("Number of items \(numberOfItems)")
            if numberOfItems > 0 {
                let itemsToMarkRead = feedModel.currentItems.prefix(through: Int(numberOfItems)).filter( { $0.unread })
                print("Number of unread items \(itemsToMarkRead.count)")
                if !itemsToMarkRead.isEmpty {
                    Task(priority: .userInitiated) {
                        let myItems = itemsToMarkRead.map( { $0 })
                        try? await NewsManager.shared.markRead(items: myItems, unread: false)
                    }
                }
            }
        }
    }

}

struct NavigationDestinationModifier: ViewModifier {
    let type: Item.Type
    let model: FeedModel

    @ViewBuilder func body(content: Content) -> some View {
#if os(iOS)
        content
            .navigationDestination(for: type) { item in
                ArticlesPageView(item: item, items: model.currentItems)
            }

#else
        content
#endif
    }
}

extension View {
    func newsNavigationDestination(type: Item.Type, model: FeedModel) -> some View {
        modifier(NavigationDestinationModifier(type: Item.self, model: model))
    }
}
