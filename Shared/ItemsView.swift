//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import Combine
import SwiftUI

struct ItemsView: View {
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @EnvironmentObject private var settings: Preferences
    @ObservedObject private var node: Node
    @StateObject var scrollViewHelper = ScrollViewHelper()
    @State private var isMarkAllReadDisabled = true
    @State private var cellHeight: CGFloat = 160.0

    init(node: Node) {
        self.node = node
    }

    var body: some View {
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.93, 700.0)
            ScrollView {
                ZStack {
                    LazyVStack(spacing: 15.0) {
                        Spacer(minLength: 1.0)
                        if !node.items.indices.isEmpty {
                            ForEach(node.items.indices, id: \.self) { index in
                                if let item = node.items[index].item {
                                    NavigationLink(destination: PagerWrapper(node: node, selectedIndex: index)) {
                                        ItemListItemViev(item: item)
                                            .tag(index)
                                            .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                            .buttonStyle(.plain)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        ContextMenuContent(item: item)
                                    }
                                }
                            }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                let unreadItems = node.items.filter( { $0.item?.unread ?? false })
                                Task {
                                    let myItems = unreadItems.map( { $0.item! })
                                    try? await NewsManager.shared.markRead(items: myItems, unread: false)
                                }
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .disabled(isMarkAllReadDisabled)
                        }
                    }
                    GeometryReader {
                        let offset = -$0.frame(in: .named("scroll")).origin.y
                        Color.clear.preference(key: ViewOffsetKey.self, value: offset)
                    }
                }
            }
            .navigationTitle(node.title)
            .coordinateSpace(name: "scroll")
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onPreferenceChange(ViewOffsetKey.self) {
                scrollViewHelper.currentOffset = $0
            }
            .onReceive(scrollViewHelper.$offsetAtScrollEnd) {
                if markReadWhileScrolling {
                    print($0)
                    let numberOfItems = max(($0 / (cellHeight + 15.0)) - 1, 0)
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
            .onReceive(node.$unreadCount) { isMarkAllReadDisabled = $0 == 0 }
            .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
        }
    }
}

//struct ItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsView(node: AnyTreeNode(StarredFeedNode()))
//    }
//}

struct LazyView<Content: View>: View {
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
