//
//  ItemsListView.swift
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
    let cellSpacing: CGFloat = 21.0
    let listRowSeparatorVisibility: Visibility = .hidden
    let listRowBackground = Color.phWhiteBackground
#endif

    // Shared environment and state properties
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
    @State private var lastOffset: CGFloat = .zero
    @State private var isScrollingToTop = false
    @State private var favIconDataByFeedId = [Int64: Data]()
    @State private var navigatedBack = false

    @Binding var selectedItem: Item?
    @Query private var feeds: [Feed]

    init(selectedItem: Binding<Item?>) {
        self._selectedItem = selectedItem
    }

    var body: some View {
        let _ = Self._printChanges()
        @Bindable var bindable = newsModel

#if os(macOS)
        macOSContentView()
            .task {
                updateFetchDescriptor()
            }
            .applySharedObservers(
                selectedNode: selectedNode,
                hideRead: hideRead,
                sortOldestFirst: sortOldestFirst,
                isNewInstall: isNewInstall,
                syncState: syncManager.syncState,
                updateFetchDescriptor: updateFetchDescriptor,
                handleSyncComplete: handleSyncComplete,
                doScrollToTop: doScrollToTop,
                modelContext: modelContext,
                fetchDescriptor: fetchDescriptor,
                setItems: { newItems in items = newItems }
            )
            .applyMacOSObservers(
                navigationItemId: bindable.navigationItemId,
                items: items,
                selectedItem: $selectedItem,
                bindable: bindable,
                handlePreviousArticle: handlePreviousArticle,
                handleNextArticle: handleNextArticle
            )
#else
        iOSContentView()
            .task {
                if navigatedBack == true {
                    navigatedBack = false
                } else {
                    updateFetchDescriptor()
                }
            }
            .navigationSubtitle(Text("\(items.count) articles"))
            .applySharedObservers(
                selectedNode: selectedNode,
                hideRead: hideRead,
                sortOldestFirst: sortOldestFirst,
                isNewInstall: isNewInstall,
                syncState: syncManager.syncState,
                updateFetchDescriptor: updateFetchDescriptor,
                handleSyncComplete: handleSyncComplete,
                doScrollToTop: doScrollToTop,
                modelContext: modelContext,
                fetchDescriptor: fetchDescriptor,
                setItems: { newItems in items = newItems }
            )
#endif
    }

#if os(macOS)
    // MARK: - macOS Content View
    @ViewBuilder
    private func macOSContentView() -> some View {
        List(items, selection: $selectedItem) { item in
            NavigationLink(value: item) {
                ItemView(item: item, faviconData: favIconDataByFeedId[item.feedId])
                    .id(item.id)
                    .contextMenu {
                        contextMenu(item: item)
                    }
            }
            .listRowSeparator(.hidden)
        }
        .onScrollPhaseChange { _, newPhase, context in
            if newPhase == .idle {
                Task {
                    try? await markRead(context.geometry.contentOffset.y + context.geometry.contentInsets.top)
                }
            }
        }
        .defaultScrollAnchor(.top)
    }

#else

    // MARK: - iOS Content View
    @ViewBuilder
    private func iOSContentView() -> some View {
        @Bindable var bindable = newsModel
        NavigationStack(path: $bindable.itemNavigationPath) {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    ScrollToTopView(reader: proxy, scrollOnChange: $scrollToTop)
                    LazyVStack(alignment: .center, spacing: 16.0) {
                        ForEach(items, id: \.id) { item in
                            // Cache the favicon lookup result outside the closure
                            let faviconData = favIconDataByFeedId[item.feedId]

                            NavigationLink(value: item) {
                                ItemView(item: item, faviconData: faviconData)
                                    .id(item.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                contextMenuContent(for: item)
                            }
                        }
                    }
                    .navigationDestination(for: Item.self) { item in
                        ArticlesPageView(itemId: item.id, items: items)
                            .environment(newsModel)
                    }
                }
                // Debounce the scroll marking with a time threshold
                .onScrollPhaseChange { _, newPhase, context in
                    if newPhase == .idle,
                       markReadWhileScrolling == true,
                       isScrollingToTop == false,
                       scenePhase == .active {
                        let currentOffset = context.geometry.contentOffset.y + context.geometry.contentInsets.top
                        // Only mark as read if scrolled significantly since last mark
                        if abs(currentOffset - lastOffset) > 50 {
                            Task {
                                try? await markRead(currentOffset)
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.top)
                .background {
                    Color.gray
                        .opacity(0.10)
                        .ignoresSafeArea(edges: .vertical)
                }
                .scrollContentBackground(.hidden)
            }
            .onChange(of: bindable.itemNavigationPath) { oldPath, newPath in
                if newPath.count < oldPath.count {
                    navigatedBack = true
                }
            }
            .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                guard newNode != oldNode else {
                    return
                }
                bindable.itemNavigationPath.removeLast(bindable.itemNavigationPath.count)
                doScrollToTop()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }

#endif

    // MARK: - Shared Helper Methods
    @MainActor
    func doScrollToTop() {
        isScrollingToTop = true
        scrollToTop.toggle()
        lastOffset = .zero
        isScrollingToTop = false
    }

    private func handleSyncComplete() {
        do {
            items = try modelContext.fetch(fetchDescriptor)
            refreshFavicons(for: items)
        } catch {
            //
        }
        doScrollToTop()
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            if newsModel.navigationItemId > 0,
               let item = items.first(where: { $0.id == newsModel.navigationItemId }) {
                newsModel.itemNavigationPath.removeLast(newsModel.itemNavigationPath.count)
                newsModel.itemNavigationPath.append(item)
                newsModel.navigationItemId = 0
                doScrollToTop()
            }
            do {
                items = try modelContext.fetch(fetchDescriptor)
                refreshFavicons(for: items)
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

#if os(macOS)
    private func handlePreviousArticle() {
        var nextIndex = items.startIndex
        if let selectedItem, let currentIndex = items.firstIndex(of: selectedItem) {
            nextIndex = currentIndex.advanced(by: -1)
        }
        nextIndex = nextIndex > items.startIndex ? nextIndex: items.startIndex
        selectedItem = items[nextIndex]
    }

    private func handleNextArticle() {
        var nextIndex = items.startIndex
        if let selectedItem, let currentIndex = items.firstIndex(of: selectedItem) {
            nextIndex = currentIndex.advanced(by: 1)
        }
        nextIndex = nextIndex > items.endIndex ? items.startIndex : nextIndex
        selectedItem = items[nextIndex]
    }
#endif

    // Extracted to avoid recreating the view on every render
    @ViewBuilder
    private func contextMenuContent(for item: Item) -> some View {
        Button {
            Task {
                await newsModel.toggleItemRead(item: item)
            }
        } label: {
            Label(item.unread ? "Read" : "Unread",
                  systemImage: item.unread ? "eye" : "eye.slash")
        }
        Button {
            Task {
                await newsModel.toggleItemStarred(item: item)
            }
        } label: {
            Label(item.starred ? "Unstar" : "Star",
                  systemImage: item.starred ? "star" : "star.fill")
        }
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
        guard offset > lastOffset else {
            return
        }

        // Defer the update to avoid blocking
        defer { lastOffset = offset }

        let cellHeight: CGFloat = compactView ? .compactCellHeight : .defaultCellHeight
        let numberOfItems = Int(max((offset / (cellHeight + cellSpacing)), 0))

        guard numberOfItems > 0 else { return }

        // Use a more efficient approach - only check items that could be visible
        let maxVisibleIndex = min(numberOfItems, items.count)
        let itemsToMarkRead = items[0..<maxVisibleIndex].filter { $0.unread }

        guard !itemsToMarkRead.isEmpty else { return }

        await newsModel.markItemsRead(items: Array(itemsToMarkRead))
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
                refreshFavicons(for: items)
            } catch {
                //
            }
        }
    }

    private func refreshFavicons(for items: [Item]) {
        let feedIds = Set(items.map { $0.feedId })
        guard !feedIds.isEmpty else {
            favIconDataByFeedId.removeAll()
            return
        }
        let descriptor = FetchDescriptor<FavIcon>(predicate: #Predicate<FavIcon> { feedIds.contains($0.id) })
        do {
            let favIcons = try modelContext.fetch(descriptor)
            var favIconDict = [Int64: Data]()
            for favIcon in favIcons {
                if let data = favIcon.icon {
                    favIconDict[favIcon.id] = data
                }
            }
            favIconDataByFeedId = favIconDict
        } catch {
            favIconDataByFeedId.removeAll()
        }
    }
}

// MARK: - View Modifiers for Shared Observers
extension View {
    func applySharedObservers(
        selectedNode: Data?,
        hideRead: Bool,
        sortOldestFirst: Bool,
        isNewInstall: Bool,
        syncState: SyncState,
        updateFetchDescriptor: @escaping () -> Void,
        handleSyncComplete: @escaping () -> Void,
        doScrollToTop: @escaping () -> Void,
        modelContext: ModelContext,
        fetchDescriptor: FetchDescriptor<Item>,
        setItems: @escaping ([Item]) -> Void
    ) -> some View {
        self
            .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                guard oldNode != newNode else { return }
                updateFetchDescriptor()
            }
            .onChange(of: hideRead, initial: true) { oldValue, newValue in
                guard oldValue != newValue else { return }
                updateFetchDescriptor()
            }
            .onChange(of: sortOldestFirst, initial: true) { oldValue, newValue in
                guard oldValue != newValue else { return }
                updateFetchDescriptor()
            }
            .onChange(of: isNewInstall) { _, _ in
                updateFetchDescriptor()
            }
            .onChange(of: syncState) { _, newValue in
                if newValue == .idle {
                    handleSyncComplete()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .articlesUpdated)) { _ in
                do {
                    let newItems = try modelContext.fetch(fetchDescriptor)
                    setItems(newItems)
                } catch {
                    //
                }
            }
    }
}

#if os(macOS)
extension View {
    func applyMacOSObservers(
        navigationItemId: Int64,
        items: [Item],
        selectedItem: Binding<Item?>,
        bindable: NewsModel,
        handlePreviousArticle: @escaping () -> Void,
        handleNextArticle: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: navigationItemId) { _, newId in
                Logger.app.debug("Getting new item: \(newId)")
                if newId > 0,
                   let item = items.first(where: { $0.id == bindable.navigationItemId }) {
                    selectedItem.wrappedValue = item
                    bindable.navigationItemId = 0
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .previousArticle)) { _ in
                handlePreviousArticle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .nextArticle)) { _ in
                handleNextArticle()
            }
    }
}
#endif

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
