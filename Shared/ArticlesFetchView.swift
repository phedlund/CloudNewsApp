//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Combine
import Kingfisher
import SwiftUI

struct ArticlesFetchView: View {
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true

    @EnvironmentObject private var favIconRepository: FavIconRepository
    @ObservedObject private var nodeRepository: NodeRepository

    @Namespace private var topID

    @FetchRequest private var items: FetchedResults<CDItem>

    @State private var selectedSort = ItemSort.default
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var path = NavigationPath()

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
        let _ = print("Selected node \(nodeRepository.currentNode ?? EmptyNodeGuid)")
        GeometryReader { geometry in
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            NavigationStack(path: $path) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Rectangle()
                            .fill(.clear)
                            .frame(height: 1)
                            .id(topID)
                        LazyVStack(spacing: 15.0) {
                            let _ = print("Items count \(items.count)")
                            ForEach(items, id: \.id) { item in
                                NavigationLink(value: item) {
                                    ItemListItemViev(item: item)
                                        .environmentObject(favIconRepository)
                                        .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                        .contextMenu {
                                            ContextMenuContent(item: item)
                                        }
                                }
                                .buttonStyle(ClearSelectionStyle())
                            }
                            .navigationDestination(for: CDItem.self) { item in
                                ArticlesPageView(item: item, items: Array(items))
                            }
                            .listRowBackground(Color.pbh.whiteBackground)
                            .listRowSeparator(.hidden)
                        }
                        .background(GeometryReader {
                            Color.clear
                                .preference(key: ViewOffsetKey.self,
                                            value: -$0.frame(in: .named("scroll")).origin.y)
                        })
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
                    //                                .toolbar {
                    //                                    ItemListToolbarContent(node: node)
                    //                                }
                    .onChange(of: $sortOldestFirst.wrappedValue) { newValue in
                        items.sortDescriptors = newValue ? ItemSort.oldestFirst.descriptors : ItemSort.default.descriptors
                    }
                    .onChange(of: $hideRead.wrappedValue) { _ in
                        items.nsPredicate = nodeRepository.predicate
                    }
                    .onChange(of: $compactView.wrappedValue) {
                        cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                    }
                    .onChange(of: nodeRepository.predicate) {
                        items.nsPredicate = $0
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
                }
            }
        }
    }

//    private func updatePredicate(nodeIdString: String) {
//        print("Setting predicate")
//        var predicate1 = NSPredicate(value: true)
//        if hideRead {
//            predicate1 = NSPredicate(format: "unread == true")
//        }
//        switch NodeType.fromString(typeString: nodeIdString) {
//        case .empty:
//            items.nsPredicate = NSPredicate(value: false)
//        case .all:
//            items.nsPredicate = NSPredicate(value: true)
//        case .starred:
//            items.nsPredicate = NSPredicate(format: "starred == true")
//        case .folder(id:  let id):
//            if let feedIds = CDFeed.idsInFolder(folder: id) {
//                let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
//                items.nsPredicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
//            }
//        case .feed(id: let id):
//            let predicate2 = NSPredicate(format: "feedId == %d", id)
//            items.nsPredicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
//        }
//    }
}
