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
    @AppStorage(SettingKeys.selectedNode) private var selectedNode = ""

    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var favIconRepository: FavIconRepository

    @State private var cellHeight: CGFloat = .defaultCellHeight

    private let offsetItemsDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetItemsPublisher: AnyPublisher<CGFloat, Never>



    private var didSelectNextItem =  NotificationCenter.default.publisher(for: .nextItem)
    private var didSelectPreviousItem =  NotificationCenter.default.publisher(for: .previousItem)

    init() {
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cellWidth = CGFloat.infinity
            let cellSize = CGSize(width: cellWidth, height: cellHeight)
            VStack {
                ScrollViewReader { proxy in
                    List(model.currentItems.indices, id: \.self, selection: $model.currentItemID) { index in
                        let item = model.currentItems[index]
                        ItemRow(item: item, itemImageManager: ItemImageManager(item: item), isHorizontalCompact: false, isCompact: compactView, size: cellSize)
                                .id(index)
                                .tag(item.objectID)
                                .environmentObject(favIconRepository)
                                .frame(height: cellHeight, alignment: .center)
                                .contextMenu {
                                    ContextMenuContent(item: item)
                                }
                                .alignmentGuide(.listRowSeparatorLeading) { _ in
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
                        .onChange(of: $selectedNode.wrappedValue) { _ in
                            proxy.scrollTo(0, anchor: .top)
                        }
                        .onReceive(didSelectPreviousItem) { _ in
                            let current = model.currentItemID
                            if let currentIndex = model.currentItems.first(where: { $0.objectID == current }) {
                                model.currentItemID = model.currentItems.element(before: currentIndex)?.objectID
                            }
                        }
                        .onReceive(didSelectNextItem) { _ in
                            let current = model.currentItemID
                            if let currentIndex = model.currentItems.first(where: { $0.objectID == current }) {
                                model.currentItemID = model.currentItems.element(after: currentIndex)?.objectID
                            }
                        }
                    }
                    .listStyle(.automatic)
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
                        if markReadWhileScrolling {
                            Task.detached {
                                await markRead(newOffset)
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
