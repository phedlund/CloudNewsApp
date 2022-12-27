//
//  ArticlesFetchView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 12/3/22.
//

import Kingfisher
import SwiftUI

struct ArticlesFetchView2: View {
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false

    @ObservedObject var model: FeedModel

    @FetchRequest(sortDescriptors: ItemSort.default.descriptors)
    private var items: FetchedResults<CDItem>

    @State var selectedSort = ItemSort.default

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15.0) {
                let _ = print("Items count \(items.count)")
                ForEach(items, id: \.id) { item in
                    NavigationLink(value: item) {
                        ItemListItemViev(item: item)
//                            .environmentObject(favIconRepository)
                            .frame(width: 700, height: 190, alignment: .center)
//                            .contextMenu {
//                                ContextMenuContent(item: item)
//                            }
                    }
                    .buttonStyle(ClearSelectionStyle())
                }
                .listRowBackground(Color.pbh.whiteBackground)
                .listRowSeparator(.hidden)
            }
            .navigationDestination(for: CDItem.self) { item in
                ArticlesPageView(item: item, items: Array(items))
                    .environmentObject(settings)
            }
        }
        .navigationTitle(model.currentNode.title)
        .task(id: model.currentNode.id) {
            do {
                let itemsWithoutImageLink = items.filter({ $0.imageLink == nil || $0.imageLink == "data:null" })
                if !itemsWithoutImageLink.isEmpty {
                    try await ItemImageFetcher.shared.itemURLs(itemsWithoutImageLink)
                }
            } catch  { }
        }
        .onChange(of: $sortOldestFirst.wrappedValue) { newValue in
            items.sortDescriptors = newValue ? ItemSort.oldestFirst.descriptors : ItemSort.default.descriptors
        }
        .onChange(of: $model.currentNode.wrappedValue) {
            var predicate1 = NSPredicate(value: true)
            if hideRead {
                predicate1 = NSPredicate(format: "unread == true")
            }
            switch $0.nodeType {
            case .empty:
                items.nsPredicate = NSPredicate(value: false)
            case .all:
                items.nsPredicate = NSPredicate(value: true)
            case .starred:
                items.nsPredicate = NSPredicate(format: "starred == true")
            case .folder(id:  let id):
                if let feedIds = CDFeed.idsInFolder(folder: id) {
                    let predicate2 = NSPredicate(format: "feedId IN %@", feedIds)
                    items.nsPredicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
                }
            case .feed(id: let id):
                let predicate2 = NSPredicate(format: "feedId == %d", id)
                items.nsPredicate = NSCompoundPredicate(type: .and, subpredicates: [predicate1, predicate2])
            }
        }
    }
}
