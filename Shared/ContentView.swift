//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

//NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

import Combine
import SwiftUI
import CoreData

struct ContentView: View {
#if !os(macOS)
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    @KeychainStorage(StorageKeys.username) var username: String = ""
    @KeychainStorage(StorageKeys.password) var password: String = ""
    @AppStorage(StorageKeys.markReadWhileScrolling) private var markReadWhileScrolling: Bool = true
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0

    @ObservedObject var model: FeedModel
    @ObservedObject var settings: Preferences
    @ObservedObject private var node: Node

    @Namespace var topID

    private let offsetDetector = CurrentValueSubject<CGFloat, Never>(0)
    private let offsetPublisher: AnyPublisher<CGFloat, Never>

    @State private var isShowingLogin = false
    @State private var addSheet: AddType?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var nodeSelection: Node.ID?
    @State private var itemSelection: ArticleModel.ID?
    @State private var selectedItem: ArticleModel?
    @State private var path = NavigationPath()
    @State private var cellHeight: CGFloat = 160.0

    private var isNotLoggedIn: Bool {
        return username.isEmpty || password.isEmpty
    }

    init(model: FeedModel, settings: Preferences) {
        self.model = model
        self.settings = settings
        _nodeSelection = State(initialValue: settings.selectedNode)
        node = model.currentNode
        self.offsetPublisher = offsetDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }

    var body: some View {
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } detail: {
            ZStack {
                if let nodeSelection, node.id != EmptyNodeGuid {
                    GeometryReader { geometry in
                        let cellWidth = min(geometry.size.width * 0.93, 700.0)
                        OptionalNavigationStack(path: $path) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(height: 1)
                                        .id(topID)
                                    LazyVStack(spacing: 15.0) {
                                        ForEach(node.items, id: \.id) { item in
                                            OptionalNavigationLink(model: item) {
                                                ItemListItemViev(model: item)
                                                    .tag(item.id)
                                                    .environmentObject(settings)
                                                    .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                                    .contextMenu {
                                                        ContextMenuContent(model: item)
                                                    }
                                            }
                                            .buttonStyle(ClearSelectionStyle())
                                        }
                                        .listRowBackground(Color.pbh.whiteBackground)
                                        .listRowSeparator(.hidden)
                                    }
                                    .scrollContentBackground(Color.pbh.whiteBackground)
                                    .navigationDestination(for: ArticleModel.self) { item in
                                        ArticlesPageView(item: item, node: node)
                                            .environmentObject(settings)
                                    }
                                    .background(GeometryReader {
                                        Color.clear.preference(key: ViewOffsetKey.self,
                                                               value: -$0.frame(in: .named("scroll")).origin.y)
                                    })
                                    .onPreferenceChange(ViewOffsetKey.self) {
                                        offsetDetector.send($0)
                                    }
                                }
                                .navigationTitle(node.title)
                                .coordinateSpace(name: "scroll")
                                .toolbar {
                                    ItemListToolbarContent(node: node)
                                }
                                .onReceive(offsetPublisher) {
                                    markRead($0)
                                }
                                .onChange(of: nodeSelection) { _ in
                                    proxy.scrollTo(topID)
                                }
                            }
                        }
                    }
                } else {
                    Text("No Feed Selected")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            isShowingLogin = isNotLoggedIn
        }
        .sheet(isPresented: $isShowingLogin) {
            NavigationView {
                SettingsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("Moving to the background!")
            appDelegate.scheduleAppRefresh()
        }
        .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
        .onChange(of: nodeSelection) {
            path.removeLast(path.count)
            if let nodeId = $0 {
                model.updateCurrentNode(nodeId)
            }
        }
        .onChange(of: itemSelection) {
            model.updateCurrentItem($0)
        }
#elseif os(macOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } content: {
            if nodeSelection != nil, node.id != EmptyNodeGuid {
                ItemsView(node: node, selectedItem: $selectedItem)
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .environmentObject(settings)
            } else {
                Text("No Feed Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let selectedItem {
                MacArticleView(item: selectedItem)
                    .environmentObject(settings)
            } else {
                Text("No Article Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
        }
        .sheet(item: $addSheet) { sheet in
            switch sheet {
            case .feed:
                VStack {
                    AddView(.feed)
                }
                .padding()
                .frame(minWidth: 400)
            case .folder:
                VStack {
                    AddView(.folder)
                }
                .padding()
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            if isNotLoggedIn {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .onChange(of: nodeSelection) {
            path.removeLast(path.count)
            if let nodeId = $0 {
                model.updateCurrentNode(nodeId)
                model.updateCurrentItem(nil)
                switch model.currentNode.nodeType {
                case .empty, .all, .starred:
                    break
                case .folder(id:  let id):
                    selectedFeed = Int(id)
                case .feed(id: let id):
                    selectedFeed = Int(id)
                }
            }
        }
        .onChange(of: selectedItem) {
            model.updateCurrentItem($0)
        }
#endif
    }

    func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            let numberOfItems = max((offset / (cellHeight + 15.0)) - 1, 0)
            if numberOfItems > 0 {
                if let nodeSelection, let node = model.node(for: nodeSelection) {
                    let itemsToMarkRead = node.items.prefix(through: Int(numberOfItems)).filter( { $0.item?.unread ?? false })
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
    
}

//struct ContentView_Previews: PreviewProvider {
//    struct Preview: View {
//        @StateObject private var model = FeedModel()
//        @StateObject private var settings = Preferences()
//        var body: some View {
//            ContentView(model: model, settings: settings)
//        }
//    }
//    static var previews: some View {
//        Preview()
//    }
//}
//
