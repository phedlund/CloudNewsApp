//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
import Kingfisher
import SwiftUI

#if os(iOS)
struct ArticlesFetchView: View {
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




    init(nodeRepository: NodeRepository) {
        self.nodeRepository = nodeRepository
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self._items = FetchRequest(sortDescriptors: ItemSort.default.descriptors, predicate: nodeRepository.predicate)
    }
    
    var body: some View {
        let _ = Self._printChanges()
        GeometryReader { geometry in
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            NavigationStack {
                ScrollViewReader { proxy in
                    List(selection: $nodeRepository.currentItem) {
                        ForEach(Array(items.enumerated()), id: \.0) { index, item in
                            ZStack {
                                NavigationLink(value: item) {
                                    EmptyView()
                                }
                                .opacity(0)
                                HStack {
                                    Spacer()
                                    ItemRow(item: item, itemImageManager: ItemImageManager(item: item), size: CGSize(width: cellWidth, height: cellHeight))
                                        .id(index)
                                        .environmentObject(favIconRepository)
                                        .contextMenu {
                                            ContextMenuContent(item: item)
                                        }
                                    Spacer()
                                }
                                .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                                    prefKey = CGFloat(index)
                                }
                                .onPreferenceChange(ViewOffsetKey.self) {
                                    let offset = ($0 * (cellHeight + 15)) - geometry.size.height
                                    offsetItemsDetector.send(offset)
                                }
                            }
                            .onChange(of: nodeRepository.currentNode) { _ in
                                proxy.scrollTo(0, anchor: .top)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.pbh.whiteBackground)
                    }
                    .navigationDestination(for: CDItem.self) { item in
                        ArticlesPageView(item: item, items: items)
                    }
                    .listStyle(.plain)
                    .accentColor(.pbh.darkIcon)
                    .background {
                        Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                    }
                    .scrollContentBackground(.hidden)
//                    .onReceive(didSync) { _ in
//                        Task(priority: .userInitiated) {
//                            await updateImageLinks()
//                        }
//                    }
                    .onAppear {
                        cellHeight = compactView ? .compactCellHeight : .defaultCellHeight
                        items.nsPredicate = nodeRepository.predicate
                    }
//                    .task(id: nodeRepository.currentNode, priority: .userInitiated) {
//                        await updateImageLinks()
//                    }
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
                        try? await ItemReadManager.shared.markRead(items: myItems, unread: false)
                    }
                }
            }
        }
    }

}
#endif
