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

    @State private var selection: Int? = 0

    init(node: Node) {
        self.node = node
    }

    var body: some View {
#if !os(macOS)
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.93, 700.0)
            ScrollView {
                ZStack {
                    LazyVStack(spacing: 15.0) {
                        Spacer(minLength: 1.0)
                        if !node.items.indices.isEmpty {
                            ForEach(Array(node.items.enumerated()), id: \.1.id) { index, item in
                                NavigationLink(destination: PagerWrapper(node: node, selectedIndex: index)) {
                                    ItemListItemViev(model: item)
                                        .tag(index)
                                        .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                }
                                .buttonStyle(ClearSelectionStyle())
                                .contextMenu {
                                    ContextMenuContent(item: item.item!)
                                }
                            }
                        }
                    }
                    .toolbar(content: itemsToolBarContent)
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
                markRead($0)
            }
            .onReceive(node.$unreadCount) { isMarkAllReadDisabled = $0 == 0 }
            .onReceive(node.$items) {
                for item in $0 {
                    if let cdItem = item.item {
                        if let imageLink = cdItem.imageLink, !imageLink.isEmpty {
                            continue
                        }
                        ItemImageFetcher().itemURL(cdItem)
                    }
                }
            }
            .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
        }
#else
        GeometryReader { geometry in
            let viewWidth = geometry.size.width
            let cellWidth: CGFloat = min(viewWidth * 0.93, 700.0)
            ZStack {
                List(selection: $selection) {
                    ForEach(Array(node.items.enumerated()), id: \.1.id) { index, item in
                        NavigationLink(destination: PagerWrapper(node: node, selectedIndex: index)) {
                            ItemListItemViev(model: item)
                                .tag(index)
                                .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                .listRowBackground(Color.pbh.whiteBackground)
                        }
                        .padding(.leading, 7)
                        .listRowBackground(Color.pbh.whiteBackground)
                        .contextMenu {
                            ContextMenuContent(item: item.item!)
                        }
                    }
                    .listRowBackground(Color.pbh.whiteBackground)
                }
                .listStyle(.bordered)
                .listRowBackground(Color.pbh.whiteBackground)
                .toolbar(content: itemsToolBarContent)
                .coordinateSpace(name: "scroll")
                GeometryReader {
                    let offset = -$0.frame(in: .named("scroll")).origin.y
                    Color.clear.preference(key: ViewOffsetKey.self, value: offset)
                }
            }
            .padding(.horizontal, -7)
            .navigationTitle(node.title)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onPreferenceChange(ViewOffsetKey.self) {
                scrollViewHelper.currentOffset = $0
            }
            .onReceive(scrollViewHelper.$offsetAtScrollEnd) {
                markRead($0)
            }
            .onReceive(node.$unreadCount) { isMarkAllReadDisabled = $0 == 0 }
            .onReceive(node.$items) { _ in
                Task {
                    do {
                        try await ItemImageFetcher().itemURLs()
                    } catch { }
                }
            }
            .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
        }
#endif
    }

    @ToolbarContentBuilder
    func itemsToolBarContent() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
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

    private func markRead(_ offset: CGFloat) {
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

struct ClearSelectionStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(Color.clear)
    }
}
