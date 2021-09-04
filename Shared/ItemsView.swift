//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @State private var preferences = [ObjectIdentifier: CGRect]()
    @FetchRequest var items: FetchedResults<CDItem>
    @ObservedObject var node: Node<TreeNode>

    init(_ node: Node<TreeNode>) {
        self.node = node
        self._items = FetchRequest(sortDescriptors: node.sortDescriptors, predicate: node.predicate)
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(items, id: \.self) { item in
                    // Workaround to hide disclosure indicator
                    ZStack(alignment: .center) {
                        NavigationLink(destination: ArticleView(item: item)) {
                            EmptyView()
                        }
                        .opacity(0)
                        ItemListItemViev(item: item)
                            .contextMenu {
                                let isUnRead = item.unread
                                let isStarred = item.starred
                                Button {
                                    Task {
                                        try? await NewsManager.shared.markRead(items: [item], unread: !isUnRead)
                                    }
                                } label: {
                                    Label {
                                        Text(isUnRead ? "Read" : "Unread")
                                    } icon: {
                                        Image(systemName: isUnRead ? "eye" : "eye.slash")
                                    }
                                }
                                Button {
                                    Task {
                                        try? await NewsManager.shared.markStarred(item: item, starred: !isStarred)
                                    }
                                } label: {
                                    Label {
                                        Text(isStarred ? "Unstar" : "Star")
                                    } icon: {
                                        Image(systemName: isStarred ? "star" : "star.fill")
                                    }
                                }
                            }
                            .frame(minWidth: 300,
                                   idealWidth: 700,
                                   maxWidth: 700,
                                   minHeight: 85,
                                   idealHeight: 160,
                                   maxHeight: 160,
                                   alignment: .center)
                            .onDisappear {
                                checkMarkingRead(item: item)
                            }
                            .anchorPreference(key: RectPreferences<ObjectIdentifier>.self, value: .bounds) {
                                [item.id: geometry[$0]]
                            }
                            .onPreferenceChange(RectPreferences<ObjectIdentifier>.self) { rects in
                                if let newPreference = rects.first {
                                    self.preferences[newPreference.key] = newPreference.value
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
    }

    fileprivate func checkMarkingRead(item: CDItem) {
        let nodeFrame = preferences[item.id] ?? .zero
        if markReadWhileScrolling,
           nodeFrame.origin.y < 0,
           (abs(nodeFrame.origin.y) - nodeFrame.size.height) > 0,
           item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

}

//struct ItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsView(node: AnyTreeNode(StarredFeedNode()))
//    }
//}
