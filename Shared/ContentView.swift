//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import Combine
import SwiftUI

struct ContentView: View {
#if !os(macOS)
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    @Environment(\.scenePhase) var scenePhase
    @KeychainStorage(StorageKeys.username) var username = ""
    @KeychainStorage(StorageKeys.password) var password = ""
    @AppStorage(StorageKeys.server) private var server = ""
    @AppStorage(StorageKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed = 0

    @ObservedObject var model: FeedModel
    @ObservedObject var settings: Preferences
    @ObservedObject var favIconRepository: FavIconRepository
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
    @State private var items = [ArticleModel]()
    @State private var cellHeight: CGFloat = .defaultCellHeight

    private var isNotLoggedIn: Bool {
        return server.isEmpty || username.isEmpty || password.isEmpty
    }

    init(model: FeedModel, settings: Preferences, favIconRepository: FavIconRepository) {
        self.model = model
        self.settings = settings
        self.favIconRepository = favIconRepository
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
                .environmentObject(favIconRepository)
        } detail: {
            ZStack {
                if let nodeSelection, node.id != EmptyNodeGuid {
                    GeometryReader { geometry in
                        let cellWidth = min(geometry.size.width * 0.93, 700.0)
                        NavigationStack(path: $path) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(height: 1)
                                        .id(topID)
                                    LazyVStack(spacing: 15.0) {
                                        ForEach(items, id: \.id) { item in
                                            NavigationLink(value: item) {
                                                ItemListItemViev(model: item)
                                                    .environmentObject(settings)
                                                    .environmentObject(favIconRepository)
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
                                    .scrollContentBackground(.hidden)
                                    .navigationDestination(for: ArticleModel.self) { item in
                                        ArticlesPageView(item: item, node: model.currentNode)
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
                                .onReceive(offsetPublisher) { newOffset in
                                    Task.detached {
                                        await markRead(newOffset)
                                    }
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
        .onReceive(settings.$compactView) { cellHeight = $0 ? .compactCellHeight : .defaultCellHeight }
        .onChange(of: nodeSelection) {
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
                Task {
                    await model.currentNode.fetchData()
                }
            }
        }
        .onChange(of: selectedItem) {
            model.updateCurrentItem($0)
        }
        .onChange(of: model.currentItem) {
            selectedItem = $0
        }
        .onChange(of: node.items) {
            items = $0
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("Active")
                nodeSelection = settings.selectedNode
                Task {
                    await model.currentNode.fetchData()
                }
            } else if newPhase == .inactive {
                print("Inactive")
            } else if newPhase == .background {
                print("Background")
                appDelegate.scheduleAppRefresh()
            }
        }
#elseif os(macOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
                .environmentObject(favIconRepository)
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
                Task {
                    await model.currentNode.fetchData()
                }
            }
        }
        .onChange(of: selectedItem) {
            model.updateCurrentItem($0)
        }
        .onChange(of: model.currentItem) {
            selectedItem = $0
        }
#endif
    }

    func markRead(_ offset: CGFloat) {
        if markReadWhileScrolling {
            let numberOfItems = max((offset / (cellHeight + 15.0)) - 1, 0)
            if numberOfItems > 0 {
                if let nodeSelection, let node = model.node(for: nodeSelection) {
                    let itemsToMarkRead = node.items.prefix(through: Int(numberOfItems)).filter( { $0.item.unread })
                    if !itemsToMarkRead.isEmpty {
                        Task(priority: .userInitiated) {
                            let myItems = itemsToMarkRead.map( { $0.item })
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
