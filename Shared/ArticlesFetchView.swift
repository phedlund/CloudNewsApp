//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
import CoreData
import Kingfisher
import SwiftUI

#if os(iOS)
struct ArticlesFetchView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.selectedNode) private var selectedNode = ""

    @EnvironmentObject private var favIconRepository: FavIconRepository

    @FetchRequest private var items: FetchedResults<CDItem>
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var currentItem: NSManagedObjectID?
    @State private var isHorizontalCompact = false

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>

    private var didSync = NotificationCenter.default.publisher(for: .syncComplete)




    init(predicate: NSPredicate) {
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self._items = FetchRequest(sortDescriptors: ItemSort.default.descriptors, predicate: predicate)
    }
    
    var body: some View {
        let _ = Self._printChanges()
        GeometryReader { geometry in
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            NavigationStack {
                ScrollViewReader { proxy in
                    List(items.indices, id: \.self, selection: $currentItem) { index in
                        let item = items[index]
                        ZStack {
                            NavigationLink(value: item) {
                                EmptyView()
                            }
                            .opacity(0)
                            HStack {
                                Spacer()
                                ItemRow(itemImageManager: ItemImageManager(item: item), itemDisplay: item.toDisplayItem(), size: cellSize, isHorizontalCompact: isHorizontalCompact)
                                    .id(index)
                                    .environmentObject(favIconRepository)
                                    .contextMenu {
                                        ContextMenuContent(item: item)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if item.starred {
                                            Image(systemName: "star.fill")
                                                .padding([.top, .trailing],  .paddingSix)
                                        }
                                    }
                                    .overlay {
                                        if !item.unread, !item.starred {
                                            Color.white.opacity(0.6)
                                        }
                                    }
                                Spacer()
                            }
                            .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                                prefKey = CGFloat(index)
                            }
                            .onPreferenceChange(ViewOffsetKey.self) {
                                let offset = ($0 * (cellHeight + 21)) - geometry.size.height
                                offsetItemsDetector.send(offset)
                            }
                        }
                        .onChange(of: $selectedNode.wrappedValue) { _ in
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.pbh.whiteBackground)
                    }
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
                .onAppear {
                    cellHeight = compactView ? .compactCellHeight : .defaultCellHeight
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
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        isHorizontalCompact = horizontalSizeClass == .compact
                    default:
                        break
                    }
                }
            }
        }
    }

    private func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            print(offset)
            let numberOfItems = max((offset / (cellHeight + 21)) - 1, 0)
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
