//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @FetchRequest var items: FetchedResults<CDItem>
    @ObservedObject var node: Node<TreeNode>
    @State private var preferences = [ObjectIdentifier: CGRect]()
    @State private var isMarkAllReadDisabled = true
    @State private var readItems = [CDItem]()

    let operationQueue = OperationQueue.main

    init(_ node: Node<TreeNode>) {
        self.node = node
        self._items = FetchRequest(sortDescriptors: node.sortDescriptors, predicate: node.predicate)
    }

    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.95, 700.0)
            let cellHeight: CGFloat = 160.0  /*85*/
            let _ = print("Redrawing list")
            List {
                ForEach(items, id: \.self.id) { item in
                    // Workaround to hide disclosure indicator
                    ZStack(alignment: .center) {
                        NavigationLink(destination: NavigationLazyView(ArticlesPageView(items: items, selectedIndex: item.id))) {
                            EmptyView()
                        }
                        .opacity(0)
                        ItemListItemViev(item: item)
                            .tag(item.id)
                            .frame(width: cellWidth, height: cellHeight, alignment: .center)
                            .anchorPreference(key: RectPreferences<ObjectIdentifier>.self, value: .bounds) {
                                [item.id: geometry[$0]]
                            }
                            .onPreferenceChange(RectPreferences<ObjectIdentifier>.self) { rects in
                                if let newPreference = rects.first {
                                    self.preferences[newPreference.key] = newPreference.value
                                    if markReadWhileScrolling,
                                       item.unread,
                                       newPreference.value.origin.y < 0,
                                       (abs(newPreference.value.origin.y) - newPreference.value.size.height) > 0
                                    {
                                        readItems.append(item)
                                        operationQueue.cancelAllOperations()
                                        operationQueue.schedule(after: OperationQueue.SchedulerTimeType.init(Date(timeIntervalSinceNow: 2.0)), tolerance: 1.0, options: nil, {
                                            let currentReadItems = readItems
                                            Task(priority: .userInitiated) {
                                                try? await NewsManager.shared.markRead(items: currentReadItems, unread: false)
                                                readItems.removeAll(where: { currentReadItems.contains($0) })
                                            }
                                        })
                                    }
                                }
                            }
                    }
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color(.clear)) // disable selection highlight
            }
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let unreadItems = items.filter( { $0.unread == true })
                        Task {
                            try? await NewsManager.shared.markRead(items: unreadItems, unread: false)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(isMarkAllReadDisabled)
                }
            })
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
        }
        .listStyle(.plain)
        .navigationTitle(node.value.title)
        .onReceive(node.$predicate) { predicate in
            items.nsPredicate = predicate
        }
        .onReceive(node.$sortDescriptors) { sortDescriptors in
            items.sortDescriptors = sortDescriptors
        }
        .onReceive(node.$unreadCount) { unreadCount in
            isMarkAllReadDisabled = unreadCount?.isEmpty ?? true
        }

    }

}

//struct ItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsView(node: AnyTreeNode(StarredFeedNode()))
//    }
//}

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
