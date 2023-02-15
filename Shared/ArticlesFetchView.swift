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
    @AppStorage(SettingKeys.compactView) private var compactView = false
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.selectedNode) private var selectedNode = ""

    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var favIconRepository: FavIconRepository

    @State private var isHorizontalCompact = true
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var currentItem: NSManagedObjectID?

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
                                ItemRow(item: item, itemImageManager: ItemImageManager(item: item), isHorizontalCompact: isHorizontalCompact, isCompact: compactView, size: cellSize)
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
                .newsNavigationDestination(type: CDItem.self, model: model)
                .listStyle(.plain)
                .accentColor(.pbh.darkIcon)
                .background {
                    Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    isHorizontalCompact = horizontalSizeClass == .compact
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
                .onChange(of: horizontalSizeClass) {
                    isHorizontalCompact = $0 == .compact
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

struct NavigationDestinationModifier: ViewModifier {
    let type: CDItem.Type
    let model: FeedModel

    @ViewBuilder func body(content: Content) -> some View {
#if os(iOS)
        content
            .navigationDestination(for: type) { item in
                ArticlesPageView(item: item, items: model.currentItems)
            }

#else
        content
#endif
    }
}

extension View {
    func newsNavigationDestination(type: CDItem.Type, model: FeedModel) -> some View {
        modifier(NavigationDestinationModifier(type: CDItem.self, model: model))
    }
}
