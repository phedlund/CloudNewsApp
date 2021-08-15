//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.hideRead) var hideRead: Bool = false
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @AppStorage(StorageKeys.sortOldestFirst) var sortOldestFirst: Bool = false
    @State private var predicate: NSPredicate?
    @State private var sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor]()
    @State var node: Node<TreeNode>
    @State private var preferences = [ObjectIdentifier: CGRect]()

    var body: some View {
        GeometryReader { geometry in
            FilteredFetchView(predicate: predicate, sortDescriptors: sortDescriptors) { (items: FetchedResults<CDItem>) in
                List {
                    ForEach(items, id: \.self) { item in
                        // Workaround to hide disclosure indicator
                        ZStack(alignment: .center) {
                            NavigationLink(destination: ArticleView(item: item)) {
                                EmptyView()
                            }
                            .opacity(0)
                            ItemListItemViev(item: item)
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
            }
        }
        .listStyle(.plain)
        .navigationTitle(node.value.title)
        .onAppear {
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)
            predicate = NSCompoundPredicate(type: .and, subpredicates: [node.value.basePredicate, unredPredicate])
        }
        .onChange(of: hideRead) { _ in
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)
            predicate = NSCompoundPredicate(type: .and, subpredicates: [node.value.basePredicate, unredPredicate])
        }
        .onChange(of: sortOldestFirst) { _ in
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : NSPredicate(value: true)
            predicate = NSCompoundPredicate(type: .and, subpredicates: [node.value.basePredicate, unredPredicate])
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
