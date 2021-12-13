//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import Combine
import CoreData
import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @EnvironmentObject private var model: FeedModel
    @EnvironmentObject private var settings: Preferences
    @StateObject var scrollViewHelper = ScrollViewHelper()
    @ObservedObject var node: Node
    @State private var isMarkAllReadDisabled = true
    @State private var navTitle = ""
    @State private var cellHeight: CGFloat = 160.0
    @State private var items = [ArticleModel]()

    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.95, 700.0)
            let _ = print("Redrawing list")
            ScrollView {
                ZStack {
                    LazyVStack(spacing: 15.0) {
                        Spacer(minLength: 1.0)
                        ForEach(items.indices, id: \.self) { index in
                            let item = items[index].item
                            NavigationLink(destination: NavigationLazyView(ArticlesPageView(items: items, selectedIndex: index))) {
                                ItemListItemViev(item: item)
                                    .tag(index)
                                    .frame(width: cellWidth, height: cellHeight, alignment: .center)
                            }
                            .contextMenu {
                                ContextMenuContent(item: item)
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                let unreadItems = items.filter( { $0.item.unread == true })
                                Task {
                                    let myItems = unreadItems.map( { $0.item })
                                    try? await NewsManager.shared.markRead(items: myItems, unread: false)
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .disabled(isMarkAllReadDisabled)
                        }
                    }
                    GeometryReader {
                        let offset = -$0.frame(in: .named("scroll")).minY
                        Color.clear.preference(key: ViewOffsetKey.self, value: offset)
                    }
                }
            }
            .navigationTitle(navTitle)
            .coordinateSpace(name: "scroll")
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onPreferenceChange(ViewOffsetKey.self) {
                scrollViewHelper.currentOffset = $0
            }.onReceive(scrollViewHelper.$offsetAtScrollEnd) {
                if markReadWhileScrolling {
                    print($0)
                    let numberOfItems = ($0 / (cellHeight + 15.0)).rounded(.down)
                    print("Number of items \(numberOfItems)")
                    if numberOfItems > 0 {
                        let itemsToMarkRead = items.prefix(through: Int(numberOfItems)).filter( { $0.item.unread })
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
//            .onReceive(settings.$hideRead) { _ in
//                items = model.nodeItems(node.nodeType)
//            }
//            .onReceive(settings.$sortOldestFirst) { _ in
//                items = model.nodeItems(node.nodeType)
//            }
            .onReceive(node.$unreadCount) { unreadCount in
                isMarkAllReadDisabled = unreadCount == 0
            }
            .onReceive(node.$title) { title in
                navTitle = title
            }
            .onReceive(node.$items) { newItems in
                items = newItems
            }
            .onReceive(settings.$compactView) { newCompactView in
                cellHeight = newCompactView ? 85.0 : 160.0
            }
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

class ScrollViewHelper: ObservableObject {
    @Published var currentOffset: CGFloat = 0
    @Published var offsetAtScrollEnd: CGFloat = 0
    
    private var cancellable: AnyCancellable?
    
    init() {
        cancellable = AnyCancellable($currentOffset
                                        .debounce(for: 0.2, scheduler: DispatchQueue.main)
                                        .dropFirst()
                                        .assign(to: \.offsetAtScrollEnd, on: self))
    }
    
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}
