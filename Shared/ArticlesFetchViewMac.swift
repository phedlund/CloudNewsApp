//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
import Kingfisher
import SwiftUI

#if os(macOS)
struct ArticlesFetchViewMac: View {
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true

    @EnvironmentObject private var favIconRepository: FavIconRepository

    @FetchRequest private var items: FetchedResults<CDItem>
    @State private var cellHeight: CGFloat = .defaultCellHeight

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>

    private var didSync = NotificationCenter.default.publisher(for: .syncComplete)
    @ObservedObject private var nodeRepository: NodeRepository

    private var didSelectNextItem =  NotificationCenter.default.publisher(for: .nextItem)
    private var didSelectPreviousItem =  NotificationCenter.default.publisher(for: .previousItem)

    init(nodeRepository: NodeRepository) {
        self.nodeRepository = nodeRepository
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self._items = FetchRequest(sortDescriptors: ItemSort.default.descriptors, predicate: nodeRepository.predicate)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = CGFloat.infinity
            VStack {
                ScrollViewReader { proxy in
                    List(selection: $nodeRepository.currentItem) {
                        ForEach(Array(items.enumerated()), id: \.0) { index, item in
                            ItemListItemViev(item: item)
                                .tag(item.objectID)
                                .id(index)
                                .environmentObject(favIconRepository)
                                .frame(height: cellHeight, alignment: .center)
                                .contextMenu {
                                    ContextMenuContent(item: item)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                                    return 0
                                }
                                .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                                    prefKey = CGFloat(index)
                                }
                                .onPreferenceChange(ViewOffsetKey.self) {
                                    let offset = ($0 * (cellHeight + 15)) - geometry.size.height
                                    offsetItemsDetector.send(offset)
                                }
                        }
                        .listRowSeparator(.visible)
                        .listRowBackground(EmptyView())
                        .onChange(of: nodeRepository.predicate) { _ in
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .onReceive(didSelectPreviousItem) { _ in
                            let current = nodeRepository.currentItem
                            if let currentIndex = items.first(where: { $0.objectID == current }) {
                                nodeRepository.currentItem = items.element(before: currentIndex)?.objectID
                            }
                        }
                        .onReceive(didSelectNextItem) { _ in
                            let current = nodeRepository.currentItem
                            if let currentIndex = items.first(where: { $0.objectID == current }) {
                                nodeRepository.currentItem = items.element(after: currentIndex)?.objectID
                            }
                        }
                    }
                    .listStyle(.automatic)
                    .accentColor(.pbh.darkIcon)
                    .background {
                        Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                    }
                    .scrollContentBackground(.hidden)
                    .onReceive(didSync) { _ in
                        Task {
                            await updateImageLinks()
                        }
                    }
                    .onAppear {
                        items.nsPredicate = nodeRepository.predicate
                    }
                    .task(id: nodeRepository.currentNode) {
                        await updateImageLinks()
                    }
                    .onChange(of: $sortOldestFirst.wrappedValue) { newValue in
                        items.sortDescriptors = newValue ? ItemSort.oldestFirst.descriptors : ItemSort.default.descriptors
                    }
                    .onChange(of: $compactView.wrappedValue) {
                        cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                    }
                    .onReceive(offsetItemsPublisher) { newOffset in
                        if markReadWhileScrolling {
                            Task.detached {
                                await markRead(newOffset)
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateImageLinks() async {
        do {
            let itemsWithoutImageLink = items.filter({ $0.imageLink == nil || $0.imageLink == "data:null" })
            if !itemsWithoutImageLink.isEmpty {
                try await ItemImageFetcher.shared.itemURLs(itemsWithoutImageLink)
            }
        } catch  { }
    }

    private func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            print(offset)
            let numberOfItems = max((offset / (cellHeight + 15.0)) - 1, 0)
            print("Number of items \(numberOfItems)")
            if numberOfItems > 0 {
                let itemsToMarkRead = items.prefix(through: Int(numberOfItems)).filter( { $0.unread })
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
#endif
