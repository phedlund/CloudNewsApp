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

    let timer = Timer.publish(every: 3, on: .main, in: .common)
        .autoconnect()

    init(_ node: Node<TreeNode>) {
        self.node = node
        self._items = FetchRequest(sortDescriptors: node.sortDescriptors, predicate: node.predicate)
    }

    var body: some View {
        GeometryReader { geometry in
            List {
                ForEach(items, id: \.self.id) { item in
                    // Workaround to hide disclosure indicator
                    ZStack(alignment: .center) {
                        NavigationLink(destination: NavigationLazyView(ArticlesPageView(items: items, selectedIndex: item.id))) {
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
                            .tag(item.id)
                            .frame(minWidth: 300,
                                   idealWidth: 700,
                                   maxWidth: 700,
                                   minHeight: 85,
                                   idealHeight: 160,
                                   maxHeight: 160,
                                   alignment: .center)
//                            .opacity(item.unread ? 1.0 : 0.4)
//                            .onDisappear {
//                                checkMarkingRead(item: item)
//                            }
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
        .onReceive(timer) { _ in
            guard !readItems.isEmpty else { return }
            Task(priority: .background) {
                try? await NewsManager.shared.markRead(items: readItems, unread: false)
                readItems.removeAll()
            }
        }

    }

//    private func checkMarkingRead(item: CDItem) {
//        if markReadWhileScrolling,
//           item.unread,
//           let nodeFrame = preferences[item.id],
//           nodeFrame.origin.y < 0,
//           (abs(nodeFrame.origin.y) - nodeFrame.size.height) > 0
//        {
//            readItems.append(item)
//        }
//    }
//
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
