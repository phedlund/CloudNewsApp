//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import Combine
import SwiftUI

struct ItemsView: View {
    @EnvironmentObject private var feedModel: FeedModel
    @ObservedObject var node: Node
    @Binding var itemSelection: ArticleModel.ID?

    @AppStorage(StorageKeys.markReadWhileScrolling) private var markReadWhileScrolling: Bool = true
    @EnvironmentObject private var settings: Preferences
    @StateObject private var scrollViewHelper = ScrollViewHelper()
    @State private var isMarkAllReadDisabled = true
    @State private var cellHeight: CGFloat = 160.0
    @State private var path = NavigationPath()

    var body: some View {
        Self._printChanges()
        return GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.93, 700.0)
            OptionalNavigationStack(path: $path) {
                List(selection: $itemSelection) {
                    ForEach(Array(node.items.enumerated()), id: \.1.id) { index, item in
                        SingleItemView(model: item) {
                            ItemListItemViev(model: item)
                                .tag(index)
                                .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                .listRowBackground(Color.pbh.whiteBackground)
                                .contextMenu {
                                    ContextMenuContent(model: item)
                                }
                                .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                                    prefKey = CGFloat(index)
                                }
                                .onPreferenceChange(ViewOffsetKey.self) {
                                    let offset = ($0 * (cellHeight + 15)) - geometry.size.height
                                    scrollViewHelper.currentOffset = offset
                                }
                        }
                        .id(index)
                    }
                    .listRowBackground(Color.pbh.whiteBackground)
                    .listRowSeparator(.hidden)
                }
#if os(macOS)
                .listStyle(.bordered)
#endif
                .listRowBackground(Color.pbh.whiteBackground)
                .toolbar {
                    ItemListToolbarContent(node: node)
                }
                .navigationTitle(node.title)
                .background {
                    Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                }
                .onReceive(scrollViewHelper.$offsetAtScrollEnd) {
                    markRead($0)
                }
                .onReceive(node.$unreadCount) { isMarkAllReadDisabled = $0 == 0 }
                .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
            }
        }

        func markRead(_ offset: CGFloat) {
            if markReadWhileScrolling {
                print(offset)
                let numberOfItems = max((offset / (cellHeight + 15.0)) - 1, 0)
                print("Number of items \(numberOfItems)")
                if numberOfItems > 0 {
                    let itemsToMarkRead = node.items.prefix(through: Int(numberOfItems)).filter( { $0.item?.unread ?? false })
                    print("Number of unread items \(itemsToMarkRead.count)")
                    if !itemsToMarkRead.isEmpty {
                        Task(priority: .userInitiated) {
                            let myItems = itemsToMarkRead.map( { $0.item! })
                            try? await NewsManager.shared.markRead(items: myItems, unread: false)
                        }
                    }
                }
            }

        }
    }
}
//struct ItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsView(node: AnyTreeNode(StarredFeedNode()))
//    }
//}
