//
//  ContentView.swift
//  Shared
//
//  Created by Peter Hedlund on 5/24/21.
//

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

    @ObservedObject var model: FeedModel
    @ObservedObject var settings: Preferences

    private let offsetDetector: CurrentValueSubject<CGFloat, Never>
    private let offsetPublisher: AnyPublisher<CGFloat, Never>

    private let onNewFeed = NotificationCenter.default
        .publisher(for: .newFeed)
        .receive(on: RunLoop.main)

    private let onNewFolder = NotificationCenter.default
        .publisher(for: .newFolder)
        .receive(on: RunLoop.main)

    @State private var isShowingLogin = false
    @State private var addSheet: AddType?
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

    @State private var nodeSelection: Node.ID?
    @State private var path = NavigationPath()
    @State private var cellHeight: CGFloat = 160.0

    private var isNotLoggedIn: Bool {
#if !os(macOS)
        return username.isEmpty || password.isEmpty
#else
        return false
#endif
    }

    init(model: FeedModel, settings: Preferences) {
        self.model = model
        self.settings = settings
        let detector = CurrentValueSubject<CGFloat, Never>(0)
        self.offsetPublisher = detector
            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
            .dropFirst()
            .eraseToAnyPublisher()
        self.offsetDetector = detector
    }

    var body: some View {
#if os(iOS)
        NavigationSplitView {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } detail: {
            ZStack {
                if let nodeSelection, let node = model.node(for: nodeSelection) {
                    GeometryReader { geometry in
                        let cellWidth = min(geometry.size.width * 0.93, 700.0)
                        OptionalNavigationStack(path: $path) {
                            ScrollView {
                                LazyVStack(spacing: 15.0) {
                                    Spacer(minLength: 1.0)
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
        .onChange(of: nodeSelection) { _ in
            path.removeLast(path.count)
        }
#elseif os(macOS)
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            SidebarView(nodeSelection: $nodeSelection)
                .environmentObject(model)
                .environmentObject(settings)
        } content: {
            if let nodeSelection, let node = model.node(for: nodeSelection) {
                ItemsView(node: node, itemSelection: $itemSelection)
                    .navigationSplitViewColumnWidth(min: 400, ideal: 500, max: 700)
                    .environmentObject(settings)
            } else {
                Text("No Feed Selected")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let nodeSelection, let node = model.node(for: nodeSelection), let _ = itemSelection {
                MacArticleView(node: node, itemSelection: $itemSelection)
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
        .onReceive(onNewFeed) { _ in
            addSheet = .feed
        }
        .onReceive(onNewFolder) { _ in
            addSheet = .folder
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
