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
    @EnvironmentObject private var model: FeedTreeModel
    @StateObject var scrollViewHelper = ScrollViewHelper()
    @ObservedObject var node: Node<TreeNode>
    @State private var isMarkAllReadDisabled = true
    @State private var navTitle = ""

    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.95, 700.0)
            let cellHeight: CGFloat = 160.0  /*85*/
            let _ = print("Redrawing list")
            let items = model.nodeItems(node.value.nodeType)
            ScrollView {
                ZStack {
                    LazyVStack(spacing: 15.0) {
                        Spacer(minLength: 1.0)
                        ForEach(items, id: \.objectID) { item in
                            NavigationLink(destination: NavigationLazyView(ArticlesPageView(items: items, selectedIndex: item.id))) {
                                ItemListItemViev(item: item)
                                    .tag(item.id)
                                    .frame(width: cellWidth, height: cellHeight, alignment: .center)
                            }
                        }
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
                    GeometryReader {
                        let offset = -$0.frame(in: .named("scroll")).minY
                        Color.clear.preference(key: ViewOffsetKey.self, value: offset)
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ViewOffsetKey.self) {
                scrollViewHelper.currentOffset = $0
            }.onReceive(scrollViewHelper.$offsetAtScrollEnd) {
                if markReadWhileScrolling {
                    print($0)
                    let numberOfItems = ($0 / (cellHeight + 15.0)).rounded(.down)
                    print("Number of items \(numberOfItems)")
                    if numberOfItems > 0 {
                        let itemsToMarkRead = items.prefix(through: Int(numberOfItems)).filter( { $0.unread })
                        print("Number of unread items \(itemsToMarkRead.count)")
                        if !itemsToMarkRead.isEmpty {
                            Task(priority: .userInitiated) {
                                try? await NewsManager.shared.markRead(items: itemsToMarkRead, unread: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle(navTitle)
            .onReceive(node.$unreadCount) { unreadCount in
                isMarkAllReadDisabled = unreadCount?.isEmpty ?? true
            }
            .onReceive(node.$title) { title in
                navTitle = title ?? "Untitled"
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
