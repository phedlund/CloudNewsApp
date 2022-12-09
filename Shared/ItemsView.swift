//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import Combine
import SwiftUI

#if os(macOS)
struct ItemsView: View {
    @ObservedObject var node: Node
    @Binding var selectedItem: ArticleModel?

    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @EnvironmentObject private var settings: Preferences
    @State private var isMarkAllReadDisabled = true
    @State private var cellHeight: CGFloat = .defaultCellHeight

    private let offsetDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetPublisher: AnyPublisher<CGFloat, Never>

    init(node: Node, selectedItem: Binding<ArticleModel?>) {
        self.node = node
        self._selectedItem = selectedItem
        self.offsetPublisher = offsetDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }

    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.93, 700.0)
            List(selection: $selectedItem) {
                ForEach(Array(node.items.enumerated()), id: \.1.id) { index, item in
                    NavigationLink(value: item) {
                        ItemListItemViev(model: item)
                            .tag(item.id)
                            .frame(width: cellWidth, height: cellHeight, alignment: .center)
                            .listRowBackground(Color.pbh.whiteBackground)
                            .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                                prefKey = CGFloat(index)
                            }
                            .onPreferenceChange(ViewOffsetKey.self) {
                                let offset = ($0 * (cellHeight + 15)) - geometry.size.height
                                offsetDetector.send(offset)
                            }
                    }
                    .contextMenu {
                        ContextMenuContent(model: item)
                    }
                }
                .listRowBackground(Color.pbh.whiteBackground)
                .listRowSeparator(.hidden)
            }
#if os(macOS)
            .listStyle(.plain)
#endif
            .accentColor(Color.pbh.whiteBackground)
            .task {
                await node.fetchData()
            }
            .toolbar {
                ItemListToolbarContent(node: node)
            }
            .navigationTitle(node.title)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onReceive(offsetPublisher) { newOffset in
                Task.detached {
                    await markRead(newOffset)
                }
            }
            .onReceive(node.$unreadCount) { isMarkAllReadDisabled = $0 == 0 }
            .onReceive(settings.$compactView) { cellHeight = $0 ? .compactCellHeight : .defaultCellHeight }
        }
    }

    func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            print(offset)
            let numberOfItems = max((offset / (cellHeight + 15.0)) - 1, 0)
            print("Number of items \(numberOfItems)")
            if numberOfItems > 0 {
                let itemsToMarkRead = node.items.prefix(through: Int(numberOfItems)).filter( { $0.unread })
                print("Number of unread items \(itemsToMarkRead.count)")
                if !itemsToMarkRead.isEmpty {
                    Task(priority: .userInitiated) {
                        let myItems = itemsToMarkRead.map( { $0.item })
                        try? await NewsManager.shared.markRead(items: myItems, unread: false)
                    }
                }
            }
        }
    }
}
#endif

//struct ItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsView(node: AnyTreeNode(StarredFeedNode()))
//    }
//}
