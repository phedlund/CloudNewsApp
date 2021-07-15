//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

enum ModalSheet {
    case login
    case folders
    case settings
    case feedSettings
}

extension ModalSheet: Identifiable {
    var id: ModalSheet { self }
}

struct SidebarView: View {
    @AppStorage(StorageKeys.selectedFolder) private var selection: String?
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0
    @ObservedObject var nodeTree: FeedTreeModel
    @State private var isShowingSheet = false
    @State private var modalSheet: ModalSheet?

    var body: some View {
        List(selection: $selection) {
            OutlineGroup(nodeTree.feedTree.children ?? [], children: \.children) { item in
                NodeView(node: item)
                    .contextMenu {
                        switch item.value.nodeType {
                        case .all, .starred:
                            EmptyView()
                        case .folder(let folderId):
                            Button {
                                //                                    currentFolderId = folderId
                                modalSheet = .folders
                                isShowingSheet = true
                            } label: {
                                Label("Rename...", systemImage: "square.and.pencil")
                            }
                            Button(role: .destructive) {
                                //
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        case .feed(let feedId):
                            Button {
                                selectedFeed = Int(feedId)
                                modalSheet = .feedSettings
                                isShowingSheet = true
                            } label: {
                                Label("Settings...", systemImage: "gearshape")
                            }
                            Button {
                                modalSheet = .folders
                                isShowingSheet = true
                            } label: {
                                Label("Folder...", systemImage: "folder")
                            }
                            Button(role: .destructive) {
                                //
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                    }
                    .tag(item.value.sortId)
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    async {
                        do {
                            try await NewsManager().sync()
                            nodeTree.update()
                        } catch {
                            //
                        }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    modalSheet = .settings
                    isShowingSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        })
        .listStyle(.sidebar)
        .refreshable {
            do {
                try await NewsManager().sync()
                nodeTree.update()
            } catch {
                //
            }
        }
        .navigationTitle(Text("Feeds"))
        .sheet(item: $modalSheet, onDismiss: {
            isShowingSheet = false
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView(content: {
                    SettingsView(showModal: $isShowingSheet)
                })
            case .folders:
                NavigationView(content: {
                    SettingsView(showModal: $isShowingSheet)
                })
            case .feedSettings:
                NavigationView(content: {
                    FeedSettingsView()
                })
            case .login:
                NavigationView(content: {
                    SettingsView(showModal: $isShowingSheet)
                })
            }
        })
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(nodeTree: FeedTreeModel())
    }
}
