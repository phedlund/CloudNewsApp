//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.hideRead) var hideRead: Bool = false
    @AppStorage(StorageKeys.sortOldestFirst) var sortOldestFirst: Bool = false
    @State private var predicate: NSPredicate?
    @State private var sortDescriptors: [NSSortDescriptor] = [NSSortDescriptor]()

    @State var node: AnyTreeNode
    @State private var items = [CDItem]()
    
    var body: some View {
        VStack {
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
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listRowBackground(Color(.clear)) // disable selection highlight
                }
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    //
                } label: {
                    Image(systemName: "checkmark")
                }
            }
        })
        .listStyle(.plain)
        .navigationTitle(node.title)
        .onAppear {
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : nil
            predicate = unredPredicate != nil ? NSCompoundPredicate(type: .and, subpredicates: [node.basePredicate, unredPredicate!]) : node.basePredicate
        }
        .onChange(of: hideRead) { _ in
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : nil
            predicate = unredPredicate != nil ? NSCompoundPredicate(type: .and, subpredicates: [node.basePredicate, unredPredicate!]) : node.basePredicate
        }
        .onChange(of: sortOldestFirst) { _ in
            sortDescriptors = [NSSortDescriptor(key: "pubDate", ascending: sortOldestFirst)]
            let unredPredicate = hideRead ? NSPredicate(format: "unread == true") : nil
            predicate = unredPredicate != nil ? NSCompoundPredicate(type: .and, subpredicates: [node.basePredicate, unredPredicate!]) : node.basePredicate
        }
    }
}

struct ItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ItemsView(node: AnyTreeNode(StarredFeedNode()))
    }
}
