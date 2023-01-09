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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true

    @EnvironmentObject private var favIconRepository: FavIconRepository
    @ObservedObject private var nodeRepository: NodeRepository

    @Namespace private var topID

    @FetchRequest private var items: FetchedResults<CDItem>

//    private var didSync =  NotificationCenter.default.publisher(for: .syncComplete)
//    @State private var refreshID = UUID()

    @State private var cellHeight: CGFloat = .defaultCellHeight

    private let offsetItemsDetector = CurrentValueSubject<[CDItem], Never>([CDItem]())
    private let offsetItemsPublisher: AnyPublisher<[CDItem], Never>

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
                    ScrollView {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 1)
                            .id(topID)
                        LazyVStack(spacing: 11.0) {
                            let _ = print("Items: \(items.count)")
                            ForEach(items, id: \.objectID) { item in
                                NavigationLink(value: item) {
                                    ItemListItemViev(item: item)
                                        .environmentObject(favIconRepository)
                                        .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                        .contextMenu {
                                            ContextMenuContent(item: item)
                                        }
                                }
                                .buttonStyle(ClearSelectionStyle())
                                Rectangle()
                                    .fill(.clear)
                                    .frame(height: 1)
                            }
                            .navigationDestination(for: CDItem.self) { item in
                                ArticlesPageView(item: item, items: items)
                            }
                            .listRowBackground(Color.pbh.whiteBackground)
                            .listRowSeparator(.hidden)
                        }
                        .background(GeometryReader {
                            Color.clear
                                .preference(key: ViewOffsetKey.self,
                                            value: -$0.frame(in: .named("scroll")).origin.y)
                        })
//                        .onReceive(didSync) { _ in
//                            refreshID = UUID()
//                            print("generated a new UUID")
//                        }
                        .onPreferenceChange(ViewOffsetKey.self) { offset in
                            let numberOfItems = Int(max((offset / (cellHeight + 15.0)) - 1, 0))
                            if numberOfItems > 0 {
                                let allItems = Array(items).prefix(numberOfItems).filter( { $0.unread })
                                offsetItemsDetector.send(allItems)
                            }
                        }
                    }
                    .onAppear {
                        items.nsPredicate = nodeRepository.predicate
                    }
                    .task(id: nodeRepository.currentNode) {
                        do {
                            let itemsWithoutImageLink = items.filter({ $0.imageLink == nil || $0.imageLink == "data:null" })
                            if !itemsWithoutImageLink.isEmpty {
                                try await ItemImageFetcher.shared.itemURLs(itemsWithoutImageLink)
                            }
                        } catch  { }
                    }
                    .coordinateSpace(name: "scroll")
                    .onChange(of: $sortOldestFirst.wrappedValue) { newValue in
                        items.sortDescriptors = newValue ? ItemSort.oldestFirst.descriptors : ItemSort.default.descriptors
                    }
                    .onChange(of: $compactView.wrappedValue) {
                        cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                    }
                    .onChange(of: nodeRepository.predicate) { _ in
                        proxy.scrollTo(topID)
                    }
                    .onReceive(offsetItemsPublisher) { newItems in
                        if markReadWhileScrolling {
                            Task.detached {
                                Task(priority: .userInitiated) {
                                    try? await NewsManager.shared.markRead(items: newItems, unread: false)
                                }
                            }
                        }
                    }
                    .onChange(of: scenePhase) { newPhase in
                        switch newPhase {
                        case .active:
                            break
//                            refreshID = UUID()
                        case .inactive, .background:
                            break
                        @unknown default:
                            fatalError("Unknown scene phase")
                        }
                    }
                }
            }
        }
    }
}
#endif
