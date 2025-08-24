//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import OSLog
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
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.didSyncInBackground) private var didSyncInBackground = false
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true

    @State private var fetchDescriptor = FetchDescriptor<Item>()
    @State private var items = [Item]()
    @State private var scrollToTop = false
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var lastOffset: CGFloat = .zero
    @State private var isScrollingToTop = false

    @Binding var selectedItem: Item?

    @Query private var feeds: [Feed]

    init(selectedItem: Binding<Item?>) {
        self._selectedItem = selectedItem
    }

    var body: some View {
        let _ = Self._printChanges()
        @Bindable var bindable = newsModel
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
            .onChange(of: bindable.navigationItemId) { _, newId in
                Logger.app.debug("Getting new item: \(newId)")
                if newId > 0,
                   let item = items.first(where: { $0.id == bindable.navigationItemId }) {
                    selectedItem = item
                    bindable.navigationItemId = 0
                }
            }
            .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                guard oldNode != newNode else {
                    return
                }
                updateFetchDescriptor()
            }
            .onChange(of: $compactView.wrappedValue, initial: true) { _, newValue in
                cellHeight = newValue == true ? .compactCellHeight : .defaultCellHeight
            }
            .onChange(of: hideRead, initial: true) { oldValue, newValue in
                guard oldValue != newValue else {
                    return
                }
                updateFetchDescriptor()
            }
            .onChange(of: sortOldestFirst, initial: true) { oldValue, newValue in
                guard oldValue != newValue else {
                    return
                }
                updateFetchDescriptor()
            }
            .onChange(of: isNewInstall) { oldValue, newValue in
                guard oldValue != newValue else {
                    return
                }
                updateFetchDescriptor()
            }
            .onReceive(NotificationCenter.default.publisher(for: .previousArticle)) { _ in
                var nextIndex = items.startIndex
                if let selectedItem, let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: -1)
                }
                nextIndex = nextIndex > items.startIndex ? nextIndex: items.startIndex
                $selectedItem.wrappedValue = items[nextIndex]
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextArticle)) { _ in
                var nextIndex = items.startIndex
                if let selectedItem, let currentIndex = items.firstIndex(of: selectedItem) {
                    nextIndex = currentIndex.advanced(by: 1)
                }
                nextIndex = nextIndex > items.endIndex ? items.startIndex : nextIndex
                $selectedItem.wrappedValue = items[nextIndex]
            }
            .task {
                updateFetchDescriptor()
            }
#else
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            NavigationStack(path: $bindable.itemNavigationPath) {
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
                        .navigationDestination(for: Item.self) { item in
                            ArticlesPageView(itemId: item.id, items: items)
                                .environment(newsModel)
                        }
                        .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                            guard newNode != oldNode else {
                                return
                            }
                            bindable.itemNavigationPath.removeLast(bindable.itemNavigationPath.count)
                            updateFetchDescriptor()
                            doScrollToTop()
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            if newPhase == .active {
                                if bindable.navigationItemId > 0,
                                    let item = items.first(where: { $0.id == bindable.navigationItemId }) {
                                    bindable.itemNavigationPath.removeLast(bindable.itemNavigationPath.count)
                                    bindable.itemNavigationPath.append(item)
                                    bindable.navigationItemId = 0
                                    doScrollToTop()
                                }
                                do {
                                    items = try modelContext.fetch(fetchDescriptor)
                                    if let firstItem = items.first, firstItem.unread {
                                        doScrollToTop()
                                    }
                                } catch {
                                    //
                                }
                                if didSyncInBackground {
                                    didSyncInBackground = false
                                    doScrollToTop()
                                }
                            }
                        }
                        .onChange(of: syncManager.syncState) { _, newValue in
                            if newValue == .idle {
                                do {
                                    items = try modelContext.fetch(fetchDescriptor)
                                } catch {
                                    //
                                }
                                doScrollToTop()
                            }
                        }
                        .onChange(of: compactView, initial: true) { _, newValue in
                            cellHeight = newValue == true ? .compactCellHeight : .defaultCellHeight
                        }
                        .onChange(of: hideRead, initial: true) { oldValue, newValue in
                            guard oldValue != newValue else {
                                return
                            }
                            updateFetchDescriptor()
                        }
                        .onChange(of: sortOldestFirst, initial: true) { oldValue, newValue in
                            guard oldValue != newValue else {
                                return
                            }
                            updateFetchDescriptor()
                        }
                        .onChange(of: isNewInstall) { _, _ in
                            updateFetchDescriptor()
                        }
                    }
                    .onScrollPhaseChange { _, newPhase, context in
                        if newPhase == .idle {
                            Task {
                                try? await markRead(context.geometry.contentOffset.y + context.geometry.contentInsets.top)
                            }
                        }
                    }
                    .defaultScrollAnchor(.top)
                    .accentColor(.phDarkIcon)
                    .background {
                        Color.gray
                            .opacity(0.10)
                            .ignoresSafeArea(edges: .vertical)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationSubtitle(Text("\(items.count) articles"))
            .task {
                updateFetchDescriptor()
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
            Task {
                await newsModel.toggleItemRead(item: item)
            }
        } label: {
            Label {
                Text(item.unread ? "Read" : "Unread")
            } icon: {
                Image(systemName: item.unread ? "eye" : "eye.slash")
            }
        }
        Button {
            Task {
                await newsModel.toggleItemStarred(item: item)
            }
        } label: {
            Label {
                Text(item.starred ? "Unstar" : "Star")
            } icon: {
                Image(systemName: item.starred ? "star" : "star.fill")
            }
        }
    }

    private func markRead(_ offset: CGFloat) async throws {
        guard isScrollingToTop == false, scenePhase == .active, offset > lastOffset else {
            return
        }
        if markReadWhileScrolling {
            let numberOfItems = Int(max((offset / (cellHeight + cellSpacing)), 0))
            if numberOfItems > 0 {
                let itemsToMarkRead = items
                    .prefix(numberOfItems)
                    .filter( { $0.unread == true } )
                await newsModel.markItemsRead(items: Array(itemsToMarkRead))
            }
        }
        lastOffset = offset
    }

    private func updateFetchDescriptor() {
        if let nodeType = NodeType.fromData(selectedNode ?? Data()) {
            fetchDescriptor.sortBy = sortOldestFirst ? [SortDescriptor(\Item.id, order: .forward)] : [SortDescriptor(\Item.id, order: .reverse)]
            switch nodeType {
            case .empty:
                fetchDescriptor.predicate = #Predicate<Item>{ _ in false }
            case .all:
                fetchDescriptor.predicate = #Predicate<Item>{
                    if hideRead {
                        return $0.unread
                    } else {
                        return true
                    }
                }
            case .unread:
                fetchDescriptor.predicate = #Predicate<Item>{ $0.unread }
            case .starred:
                fetchDescriptor.predicate = #Predicate<Item>{ $0.starred }
            case .folder(id:  let id):
                let feedIds = feeds.filter( { $0.folderId == id }).map( { $0.id } )
                fetchDescriptor.predicate = #Predicate<Item>{
                    if hideRead {
                        return feedIds.contains($0.feedId) && $0.unread
                    } else {
                        return feedIds.contains($0.feedId)
                    }
                }
            case .feed(id: let id):
                fetchDescriptor.predicate = #Predicate<Item>{
                    if hideRead {
                        return $0.feedId == id && $0.unread
                    } else {
                        return $0.feedId == id
                    }
                }
            }
            do {
                items = try modelContext.fetch(fetchDescriptor)
            } catch {
                //
            }
        }
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
