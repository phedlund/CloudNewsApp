//
//  ItemsListView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import OSLog
import SwiftData
import SwiftUI

private struct ScrollMetrics: Equatable {
    var offset: CGFloat
    var visibleHeight: CGFloat
    var totalHeight: CGFloat
}

struct ItemsListView: View {
    // MARK: - Platform Constants
#if os(macOS)
    private let cellSpacing: CGFloat = 15.0
#else
    private let cellSpacing: CGFloat = 21.0
#endif

    // True on macOS and iPadOS (hardware keyboard supported), false on iPhone
    private var supportsKeyboardNavigation: Bool {
#if os(macOS)
        true
#else
        UIDevice.current.userInterfaceIdiom == .pad
#endif
    }

    @FocusState private var isListFocused: Bool
    @State private var scrollID: PersistentIdentifier? = nil

    // MARK: - Environment
    @Environment(NewsModel.self) private var newsModel
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    // MARK: - AppStorage
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.markReadWhileScrollingIncludingEnd) private var markReadWhileScrollingIncludingEnd = false
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.didSyncInBackground) private var didSyncInBackground = false
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true

    // MARK: - State
    @State private var fetchDescriptor = FetchDescriptor<Item>()
    @State private var items = [Item]()
    @State private var scrollToTop = false
    @State private var lastOffset: CGFloat = .zero
    @State private var scrollStoppedTask: Task<Void, Never>?
    @State private var isScrollingToTop = false
    @State private var favIconDataByFeedId = [Int64: Data]()
    @State private var navigatedBack = false

    // MARK: - Binding
    @Binding var focusedItemID: PersistentIdentifier?
    @Query private var feeds: [Feed]

    init(selectedItemID: Binding<PersistentIdentifier?>) {
        self._focusedItemID = selectedItemID
    }

    // MARK: - Body
    var body: some View {
        let _ = Self._printChanges()
        @Bindable var bindable = newsModel

#if os(macOS)
        sharedScrollView()
            .task { updateFetchDescriptor() }
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
                bindable: bindable,
                handlePreviousArticle: handlePreviousArticle,
                handleNextArticle: handleNextArticle
            )
#else
        NavigationStack(path: $bindable.itemNavigationPath) {
            sharedScrollView()
                .navigationDestination(for: Item.self) { item in
                    ArticlesPageView(itemId: item.id, items: items)
                        .environment(newsModel)
                }
                .onChange(of: bindable.itemNavigationPath) { oldPath, newPath in
                    if newPath.count < oldPath.count {
                        navigatedBack = true
                    }
                }
        }
        .task {
            if navigatedBack {
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

    // MARK: - Shared Scroll View
    @ViewBuilder
    private func sharedScrollView() -> some View {
        @Bindable var bindable = newsModel

#if os(macOS)
        baseScrollView()
            .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                guard newNode != oldNode else { return }
                doScrollToTop()
                focusedItemID = items.first?.persistentModelID
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
#else
        ScrollViewReader { proxy in
            baseScrollView(scrollProxy: proxy)
                .onChange(of: selectedNode, initial: true) { oldNode, newNode in
                    guard newNode != oldNode else { return }
                    bindable.itemNavigationPath.removeLast(bindable.itemNavigationPath.count)
                    doScrollToTop()
                    if supportsKeyboardNavigation {
                        focusedItemID = items.first?.persistentModelID
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
#endif
    }

    /// The core ScrollView, shared across all platforms.
    @ViewBuilder
    private func baseScrollView(scrollProxy: ScrollViewProxy? = nil) -> some View {
        ScrollView(.vertical) {
#if !os(macOS)
            if let proxy = scrollProxy {
                ScrollToTopView(reader: proxy, scrollOnChange: $scrollToTop)
            }
#endif
            itemList()
        }
        .scrollPosition(id: $scrollID)
        .onScrollPhaseChange { _, newPhase, context in
            guard newPhase == .idle,
                  markReadWhileScrolling,
                  !isScrollingToTop,
                  scenePhase == .active
            else { return }

            let geometry = context.geometry
            let currentOffset = geometry.contentOffset.y + geometry.contentInsets.top
            let visibleHeight = geometry.containerSize.height
            let totalHeight = geometry.contentSize.height

            if abs(currentOffset - lastOffset) > 50 {
                Task { try? await markRead(currentOffset) }
            }

            if currentOffset > 0,
               currentOffset + visibleHeight >= totalHeight - 5.0,
               markReadWhileScrollingIncludingEnd {
                Task { try? await markRead(CGFloat(Int.max)) }
            }
        }
        .defaultScrollAnchor(.top)
        .onChange(of: focusedItemID) { _, newValue in
            withAnimation { scrollID = newValue }
        }
        .onAppear {
            if supportsKeyboardNavigation {
                focusedItemID = items.first?.persistentModelID
            }
        }
        .background {
            Color.gray.opacity(0.10)
                .ignoresSafeArea(edges: .vertical)
        }
        .scrollContentBackground(.hidden)
        .ifCondition(supportsKeyboardNavigation) { view in
            view
                .focusable()
                .focusEffectDisabled()
                .focused($isListFocused)
                .onKeyPress(keys: [.downArrow, .upArrow]) { keyPress in
                    moveSelection(forward: keyPress.key == .downArrow)
                    return .handled
                }
        }
    }

    // MARK: - Shared Item List
    @ViewBuilder
    private func itemList() -> some View {
        LazyVStack(alignment: .center, spacing: 16.0) {
            ForEach(items) { item in
                let faviconData = favIconDataByFeedId[item.feedId]
                let selectionOverlay = focusedItemID == item.persistentModelID
                    ? (isListFocused ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.2))
                    : Color.clear

                let itemView = ItemView(item: item, faviconData: faviconData)
                    .overlay(RoundedRectangle(cornerRadius: 12).fill(selectionOverlay))
                    .padding(.horizontal, supportsKeyboardNavigation ? 8 : 0)
                    .contextMenu { contextMenuContent(for: item) }

                #if os(macOS)
                itemView
                    .id(item.persistentModelID)
                    .onTapGesture { focusedItemID = item.persistentModelID }
                #else
                NavigationLink(value: item) { itemView.id(item.id) }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        if supportsKeyboardNavigation {
                            focusedItemID = item.persistentModelID
                        }
                    })
                #endif
            }
        }
        .scrollTargetLayout()
    }

    // MARK: - Keyboard Navigation
    private func moveSelection(forward: Bool = true) {
        guard !items.isEmpty else { return }
        guard let currentID = focusedItemID,
              let currentIndex = items.firstIndex(where: { $0.persistentModelID == currentID })
        else {
            focusedItemID = forward ? items.first?.persistentModelID : items.last?.persistentModelID
            return
        }
        let newIndex = forward ? currentIndex + 1 : currentIndex - 1
        guard items.indices.contains(newIndex) else { return }
        focusedItemID = items[newIndex].persistentModelID
    }

    private func handlePreviousArticle() { moveSelection(forward: false) }
    private func handleNextArticle() { moveSelection(forward: true) }

    // MARK: - Shared Helpers
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
        } catch {}
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
            } catch {}
            if didSyncInBackground {
                didSyncInBackground = false
                doScrollToTop()
            }
        }
    }

    private func markRead(_ offset: CGFloat) async throws {
        guard offset > lastOffset else { return }
        defer { lastOffset = offset }
        let cellHeight: CGFloat = compactView ? .compactCellHeight : .defaultCellHeight
        let numberOfItems = Int(max((offset / (cellHeight + cellSpacing)), 0))
        guard numberOfItems > 0 else { return }
        let maxVisibleIndex = min(numberOfItems, items.count)
        let itemsToMarkRead = items[0..<maxVisibleIndex].filter { $0.unread }
        guard !itemsToMarkRead.isEmpty else { return }
        await newsModel.markItemsRead(items: Array(itemsToMarkRead))
    }

    private func updateFetchDescriptor() {
        if let nodeType = NodeType.fromData(selectedNode ?? Data()) {
            fetchDescriptor.sortBy = sortOldestFirst
                ? [SortDescriptor(\Item.id, order: .forward)]
                : [SortDescriptor(\Item.id, order: .reverse)]
            switch nodeType {
            case .empty:
                fetchDescriptor.predicate = #Predicate<Item> { _ in false }
            case .all:
                fetchDescriptor.predicate = #Predicate<Item> {
                    hideRead ? $0.unread : true
                }
            case .unread:
                fetchDescriptor.predicate = #Predicate<Item> { $0.unread }
            case .starred:
                fetchDescriptor.predicate = #Predicate<Item> { $0.starred }
            case .folder(id: let id):
                let feedIds = feeds.filter { $0.folderId == id }.map { $0.id }
                fetchDescriptor.predicate = #Predicate<Item> {
                    hideRead ? feedIds.contains($0.feedId) && $0.unread : feedIds.contains($0.feedId)
                }
            case .feed(id: let id):
                fetchDescriptor.predicate = #Predicate<Item> {
                    hideRead ? $0.feedId == id && $0.unread : $0.feedId == id
                }
            }
            do {
                items = try modelContext.fetch(fetchDescriptor)
                refreshFavicons(for: items)
            } catch {}
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

    // MARK: - Context Menu
    @ViewBuilder
    private func contextMenuContent(for item: Item) -> some View {
        Button {
            Task { await newsModel.toggleItemRead(item: item) }
        } label: {
            Label(item.unread ? "Read" : "Unread",
                  systemImage: item.unread ? "eye" : "eye.slash")
        }
        Button {
            Task { await newsModel.toggleItemStarred(item: item) }
        } label: {
            Label(item.starred ? "Unstar" : "Star",
                  systemImage: item.starred ? "star" : "star.fill")
        }
    }
}

// MARK: - Shared Observer Modifier
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
                if newValue == .idle { handleSyncComplete() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .articlesUpdated)) { _ in
                do {
                    let newItems = try modelContext.fetch(fetchDescriptor)
                    setItems(newItems)
                } catch {}
            }
    }
}

// MARK: - macOS Observer Modifier
#if os(macOS)
extension View {
    func applyMacOSObservers(
        navigationItemId: Int64,
        items: [Item],
        bindable: NewsModel,
        handlePreviousArticle: @escaping () -> Void,
        handleNextArticle: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: navigationItemId) { _, newId in
                Logger.app.debug("Getting new item: \(newId)")
                if newId > 0,
                   let _ = items.first(where: { $0.id == bindable.navigationItemId }) {
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

// MARK: - Conditional Modifier Helper
extension View {
    @ViewBuilder
    func ifCondition<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - ScrollToTopView (iOS only)
#if !os(macOS)
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
#endif

