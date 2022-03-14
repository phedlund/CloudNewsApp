//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import Combine
import CustomModalView

enum ModalSheet {
    case login
    case folderRename
    case settings
    case feedSettings
}

extension ModalSheet: Identifiable {
    var id: ModalSheet { self }
}

struct SidebarView: View {
    @EnvironmentObject private var model: FeedModel
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0
    @AppStorage(StorageKeys.selectedNode) private var selectedNode: String?
    @State private var isShowingSheet = false
    @State private var isShowingAddModal = false
    @State private var modalSheet: ModalSheet?
    @State private var isSyncing = false
    @State private var isShowingError = false
    @State private var errorMessage = ""

    private var publisher = NotificationCenter.default
        .publisher(for: .syncComplete)
        .receive(on: DispatchQueue.main)

    var body: some View {
        List(selection: $selectedNode) {
            if isShowingError {
                HStack {
                    Text(errorMessage)
                    Button {
                        isShowingError = false
                    } label: {
                        Text("Dismiss")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.75))
                .cornerRadius(10.0)
                .transition(.move(edge: .top))
            }
            OutlineGroup(model.nodes, children: \.children) { node in
                if UIDevice.current.userInterfaceIdiom == .phone {
                    NavigationLink(destination: ItemsView(node: node)) {
                        NodeView(node: node, selectedFeed: $selectedFeed, modalSheet: $modalSheet, isShowingSheet: $isShowingSheet)
                    }
                } else {
                    NavigationLink(destination: ItemsView(node: node),
                                   isActive: model.selectionBindingForId(id: node.id)) {
                        NodeView(node: node, selectedFeed: $selectedFeed, modalSheet: $modalSheet, isShowingSheet: $isShowingSheet)
                    }
                }
            }
            .accentColor(.pbh.whiteIcon)
        }
        .listStyle(.sidebar)
        .accentColor(.pbh.darkIcon)
        .refreshable {
            sync()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(isSyncing ? 1.0 : 0.0)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    sync()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isSyncing)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    modalSheet = .settings
                    isShowingSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .onReceive(publisher) { _ in
            isSyncing = false
        }
        .onChange(of: selectedNode) { newSelection in
            print(newSelection ?? "")
        }
        .navigationTitle(Text("Feeds"))
        .sheet(item: $modalSheet, onDismiss: {
            isShowingSheet = false
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView(showModal: $isShowingSheet)
                }
            case .folderRename:
                NavigationView {
                    FolderRenameView(selectedFeed: $selectedFeed)
                }
            case .feedSettings:
                NavigationView {
                    FeedSettingsView(selectedFeed)
                }
            case .login:
                NavigationView {
                    SettingsView(showModal: $isShowingSheet)
                }
            }
        })
    }

    private func sync() {
        Task {
            do {
                isSyncing = true
                try await NewsManager().sync()
                isShowingError = false
                errorMessage = ""
                model.update()
            } catch(let error as PBHError) {
                switch error {
                case .networkError(let message):
                    errorMessage = message
                default:
                    errorMessage = error.localizedDescription
                }
                isShowingError = true
                isSyncing = false
            }
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
    }
}

struct RectPreferences<NSManagedObjectID: Hashable>: PreferenceKey {
    typealias Value = [NSManagedObjectID: CGRect]

    static var defaultValue: Value { [:] }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}
