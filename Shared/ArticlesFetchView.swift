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

    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var favIconRepository: FavIconRepository

    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var currentItem: NSManagedObjectID?
    @State private var isHorizontalCompact = false

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>





    init() {
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.7), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    var body: some View {
        let _ = Self._printChanges()
        GeometryReader { geometry in
            let cellWidth = min(geometry.size.width * 0.93, 700.0)
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            NavigationStack {
                ScrollViewReader { proxy in
                    List(model.currentItems.indices, id: \.self, selection: $currentItem) { index in
                        let item = model.currentItems[index]
                        ZStack {
                            NavigationLink(value: item) {
                                EmptyView()
                            }
                            .opacity(0)
                            HStack {
                                Spacer()
                                ItemRow(item: item, itemImageManager: ItemImageManager(item: item), size: cellSize, isHorizontalCompact: isHorizontalCompact)
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
                                let offset = ($0 * (cellHeight + 21)) - geometry.size.height
                                offsetItemsDetector.send(offset)
                            }
                        }
                        .onChange(of: $selectedNode.wrappedValue) { [oldValue = selectedNode] newValue in
                            if newValue != oldValue {
                                proxy.scrollTo(0, anchor: .top)
                                offsetItemsDetector.send(0.0)
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.pbh.whiteBackground)
                    }
                }
                .navigationDestination(for: CDItem.self) { item in
                    ArticlesPageView(item: item, items: model.currentItems)
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
                .onChange(of: $compactView.wrappedValue) {
                    cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                }
                .onReceive(offsetItemsPublisher) { newOffset in
                    Task.detached {
                        await markRead(newOffset)
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
                let itemsToMarkRead = model.currentItems.prefix(through: Int(numberOfItems)).filter( { $0.unread })
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
