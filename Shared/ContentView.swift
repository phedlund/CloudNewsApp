//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

import Combine
import CoreData
import SwiftUI

struct ContentView: View {
#if !os(macOS)
    @EnvironmentObject var appDelegate: AppDelegate
#endif
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.scenePhase) var scenePhase
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.selectedFeed) private var selectedFeed = 0
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false

    @ObservedObject var model: FeedModel
    @ObservedObject var settings: Preferences
    @ObservedObject var favIconRepository: FavIconRepository

    @Namespace var topID

    private let offsetItemsDetector = CurrentValueSubject<[CDItem], Never>([CDItem]())
    private let offsetItemsPublisher: AnyPublisher<[CDItem], Never>

    @State private var node = Node(.empty, id: EmptyNodeGuid)
    @State private var isShowingLogin = false
    @State private var addSheet: AddType?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var nodeSelection: Node.ID?
    @State private var path = NavigationPath()
    @State private var cellHeight: CGFloat = .defaultCellHeight
    @State private var selectedItem: NSManagedObjectID?

    private var isNotLoggedIn: Bool {
        return server.isEmpty || username.isEmpty || password.isEmpty
    }

    init(model: FeedModel, settings: Preferences, favIconRepository: FavIconRepository) {
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self.model = model
        self.settings = settings
        self.favIconRepository = favIconRepository
        let nodeSel = settings.selectedNode
        self.node = model.node(for: nodeSel) ?? Node(.empty, id: EmptyNodeGuid)
        _nodeSelection = State(initialValue: nodeSel)
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
                if let nodeSelection, nodeSelection != EmptyNodeGuid {
                    GeometryReader { geometry in
                        let cellWidth = min(geometry.size.width * 0.93, 700.0)
                        NavigationStack(path: $path) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Rectangle()
                                        .fill(.clear)
                                        .frame(height: 1)
                                        .id(topID)
                                    ArticlesFetchView(nodeId: nodeSelection, model: model, hideRead: hideRead, sortOldestFirst: sortOldestFirst) { items in
                                        LazyVStack(spacing: 15.0) {
                                            ForEach(items, id: \.id) { item in
                                                NavigationLink(value: item) {
                                                    ItemListItemViev(item: item)
                                                        .environmentObject(settings)
                                                        .environmentObject(favIconRepository)
                                                        .frame(width: cellWidth, height: cellHeight, alignment: .center)
                                                        .contextMenu {
                                                            ContextMenuContent(item: item)
                                                        }
                                                }
                                                .buttonStyle(ClearSelectionStyle())
                                            }
                                            .listRowBackground(Color.pbh.whiteBackground)
                                            .listRowSeparator(.hidden)
                                        }
                                        .scrollContentBackground(.hidden)
                                        .navigationDestination(for: CDItem.self) { item in
                                            ArticlesPageView(item: item, items: Array(items))
                                                .environmentObject(settings)
                                        }
                                        .background(GeometryReader {
                                            Color.clear
                                                .preference(key: ViewOffsetKey.self,
                                                            value: -$0.frame(in: .named("scroll")).origin.y)
                                        })
                                        .onPreferenceChange(ViewOffsetKey.self) { offset in
                                            let numberOfItems = Int(max((offset / (cellHeight + 15.0)) - 1, 0))
                                            if numberOfItems > 0 {
                                                let allItems = Array(items).prefix(numberOfItems).filter( { $0.unread })
                                                offsetItemsDetector.send(allItems)
                                            }
                                        }
                                    }
                                }
                                .coordinateSpace(name: "scroll")
                                .toolbar {
                                    ItemListToolbarContent(node: node)
                                }
                                .onReceive(offsetItemsPublisher) { newItems in
                                    Task.detached {
                                        Task(priority: .userInitiated) {
                                            try? await NewsManager.shared.markRead(items: newItems, unread: false)
                                        }
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
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
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
                    node = model.currentNode
                }
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    nodeSelection = settings.selectedNode
                case .inactive:
                    break
                case .background:
                    appDelegate.scheduleAppRefresh()
                @unknown default:
                    fatalError("Unknown scene phase")
                }
            }
        }
#elseif os(macOS)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
                .environmentObject(favIconRepository)
        } content: {
            if let nodeSelection, nodeSelection != EmptyNodeGuid {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 1)
                                .id(topID)
                            ArticlesFetchView(nodeId: nodeSelection, model: model, hideRead: hideRead, sortOldestFirst: sortOldestFirst) { items in
                                LazyVStack(spacing: 15.0) {
                                    ForEach(items, id: \.id) { item in
                                        ItemListItemViev(item: item)
                                            .environmentObject(settings)
                                            .environmentObject(favIconRepository)
                                            .padding([.horizontal], 6)
                                            .frame(width: geometry.size.width, height: cellHeight, alignment: .center)
                                            .contextMenu {
                                                ContextMenuContent(item: item)
                                            }
                                            .onTapGesture { _ in
                                                selectedItem = item.objectID
                                            }
                                    }
                                    .listRowBackground(Color.pbh.whiteBackground)
                                    .listRowSeparator(.hidden)
                                }
                                .background(GeometryReader {
                                    Color.clear
                                        .preference(key: ViewOffsetKey.self,
                                                    value: -$0.frame(in: .named("scroll")).origin.y)
                                })
                                .onPreferenceChange(ViewOffsetKey.self) { offset in
                                    let numberOfItems = Int(max((offset / (cellHeight + 15.0)) - 1, 0))
                                    if numberOfItems > 0 {
                                        let allItems = Array(items).prefix(numberOfItems).filter( { $0.unread })
                                        offsetItemsDetector.send(allItems)
                                    }
                                }
                            }
                            .background(Color.pbh.whiteBackground)
                        }
                        .coordinateSpace(name: "scroll")
                        .navigationTitle(node.title)
                        .background {
                            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                        }
                        .toolbar {
                            ItemListToolbarContent(node: node)
                        }
                        .onReceive(offsetItemsPublisher) { newItems in
                            Task.detached {
                                Task(priority: .userInitiated) {
                                    try? await NewsManager.shared.markRead(items: newItems, unread: false)
                                }
                            }
                        }
                        .onChange(of: nodeSelection) { _ in
                            proxy.scrollTo(topID)
                        }
                        .onReceive(settings.$compactView) {
                            cellHeight = $0 ? .compactCellHeight : .defaultCellHeight
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
            } else {
                Text("No Feed Selected")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let selectedItem, let item = moc.object(with: selectedItem) as? CDItem {
                MacArticleView(item: item)
                    .environmentObject(settings)
            } else {
                Text("No Article Selected")
                    .font(.largeTitle)
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
                node = model.currentNode
            }
        }
        .onChange(of: selectedItem) { newValue in
            if let newValue, let item = moc.object(with: newValue) as? CDItem {
                model.updateCurrentItem(item)
            }
        }
#endif
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
