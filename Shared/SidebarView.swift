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
    @State private var isShowingFolderRename = false
    @State private var modalSheet: ModalSheet?
    @State private var nodeFrame: CGRect = .zero
    @State private var preferences = [ObjectIdentifier: CGRect]()

    var body: some View {
        GeometryReader { geometry in
            List(selection: $selection) {
                OutlineGroup(nodeTree.feedTree.children ?? [], children: \.children) { item in
                    NodeView(node: item)
                        .contextMenu {
                            switch item.value.nodeType {
                            case .all, .starred:
                                EmptyView()
                            case .folder(let folderId):
                                Button {
                                    selectedFeed = Int(folderId)
                                    nodeFrame = preferences[item.id] ?? .zero
                                    isShowingFolderRename = true
                                } label: {
                                    Label("Rename...", systemImage: "square.and.pencil")
                                }
                                Button(role: .destructive) {
                                    //
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(true)
                            case .feed(let feedId):
                                Button {
                                    selectedFeed = Int(feedId)
                                    modalSheet = .feedSettings
                                    isShowingSheet = true
                                } label: {
                                    Label("Settings...", systemImage: "gearshape")
                                }
                                Button(role: .destructive) {
                                    //
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(true)
                            }
                        }
                        .tag(item.value.sortId)
                        .anchorPreference(key: RectPreferences<ObjectIdentifier>.self, value: .bounds) {
                            [item.id: geometry[$0]]
                        }
                        .onPreferenceChange(RectPreferences<ObjectIdentifier>.self) { rects in
                            if let newPreference = rects.first {
                                self.preferences[newPreference.key] = newPreference.value
                            }
                        }
                }
            }
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
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
            .popover(isPresented: $isShowingFolderRename,
                     attachmentAnchor: .rect(.rect(nodeFrame)),
                     arrowEdge: .trailing) {
                FolderRenameView(showModal: $isShowingFolderRename)
            }
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(nodeTree: FeedTreeModel())
    }
}

struct RectPreferences<Item: Hashable>: PreferenceKey {
    typealias Value = [Item: CGRect]

    static var defaultValue: Value { [:] }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}
