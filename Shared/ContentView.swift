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
    @StateObject private var settings = Preferences()
    @StateObject private var favIconRepository = FavIconRepository()
    @Environment(\.managedObjectContext) private var moc
    @Environment(\.scenePhase) var scenePhase
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""
    @AppStorage(SettingKeys.server) private var server = ""
    @AppStorage(SettingKeys.markReadWhileScrolling) private var markReadWhileScrolling = true
    @AppStorage(SettingKeys.selectedFeed) private var selectedFeed = 0
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.sortOldestFirst) private var sortOldestFirst = false

    @StateObject private var nodeRepository = NodeRepository()

    @EnvironmentObject private var model: FeedModel

    @Namespace var topID

    private let offsetItemsDetector = CurrentValueSubject<[CDItem], Never>([CDItem]())
    private let offsetItemsPublisher: AnyPublisher<[CDItem], Never>

    @State private var isShowingLogin = false
    @State private var addSheet: AddType?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var selectedItem: NSManagedObjectID?

    private var isNotLoggedIn: Bool {
        return server.isEmpty || username.isEmpty || password.isEmpty
    }

    init() {
        self.offsetItemsPublisher = offsetItemsDetector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }

    var body: some View {
        let _ = Self._printChanges()
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $nodeRepository.currentNode)
                .environmentObject(model)
                .environmentObject(favIconRepository)
        } detail: {
            ZStack {
                if nodeRepository.currentNode != EmptyNodeGuid {
                    ArticlesFetchView(nodeRepository: nodeRepository)
                        .environmentObject(favIconRepository)
                        .toolbar {
                            ItemListToolbarContent(node: model.currentNode)
                        }
                } else {
                    Text("No Feed Selected")
                        .font(.largeTitle).fontWeight(.light)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(model.currentNode.title)
            .onAppear {
                isShowingLogin = isNotLoggedIn
            }
            .sheet(isPresented: $isShowingLogin) {
                NavigationView {
                    SettingsView()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    break
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
                let _ = Self._printChanges()
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        VStack {
                            Rectangle()
                                .fill(.clear)
                                .frame(height: 1)
                                .id(topID)
                            //                        ArticlesFetchView(nodeId: nodeSelection, model: model, hideRead: hideRead, sortOldestFirst: sortOldestFirst) { items in
                            List(selection: $selectedItem) {
                                ForEach(items, id: \.objectID) { item in
                                    ItemListItemViev(item: item)
                                        .environmentObject(settings)
                                        .environmentObject(favIconRepository)
                                        .padding([.horizontal], 6)
                                        .frame(width: geometry.size.width, height: cellHeight, alignment: .center)
                                        .contextMenu {
                                            ContextMenuContent(item: item)
                                        }
                                        .listRowBackground(Color.pbh.whiteBackground)
                                        .listRowSeparator(.hidden)
                                }
                            }
                            .background(GeometryReader {
                                Color.clear
                                    .preference(key: ViewOffsetKey.self,
                                                value: -$0.frame(in: .named("scroll")).origin.y)
                            })
                            .onPreferenceChange(ViewOffsetKey.self) { offset in
                                let numberOfItems = Int(max((offset / (cellHeight + 15.0)) - 1, 0))
                                if numberOfItems > 0 {
                                    let allItems = model.currentItems.prefix(numberOfItems).filter( { $0.unread })
                                    offsetItemsDetector.send(allItems)
                                }
                            }
                            //                        }
                            .coordinateSpace(name: "scroll")
                        }
                        //                        .coordinateSpace(name: "scroll")
                        .navigationTitle(node.title)
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
                settings.selectedNode = nodeId
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
                items = model.currentItems
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
