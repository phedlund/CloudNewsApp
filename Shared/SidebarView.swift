//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import Combine

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
    @EnvironmentObject private var preferences: Preferences
    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0
    @AppStorage(StorageKeys.selectedNode) private var selectedNode: String = AllNodeGuid
    @State private var isShowingAddModal = false
    @State private var modalSheet: ModalSheet?
    @State private var isSyncing = false
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var selection: String? = AllNodeGuid

    private var publisher = NotificationCenter.default
        .publisher(for: .syncComplete)
        .receive(on: DispatchQueue.main)

    var body: some View {
        print(Self._printChanges())
        return List(selection: $selection) {
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
                NavigationLink(tag: node.id, selection: $selection) {
                    ItemsView(node: node)
                        .environmentObject(preferences)
                } label: {
                    NodeView(node: node, selectedFeed: $selectedFeed, modalSheet: $modalSheet)
                }
            }
            .accentColor(.pbh.whiteIcon)
        }
        .listStyle(.sidebar)
        .accentColor(.pbh.darkIcon)
        .refreshable {
            sync()
        }
        .onAppear {
            selection = selectedNode
        }
        .toolbar {
#if !os(macOS)
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
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
#endif
        }
        .onReceive(publisher) { _ in
            isSyncing = false
        }
        .onChange(of: selection) {
            print("Selected node is \($0 ?? "")")
        }
        .navigationTitle(Text("Feeds"))
        .sheet(item: $modalSheet, onDismiss: {
            modalSheet = nil
        }, content: { sheet in
            switch sheet {
            case .settings:
                NavigationView {
                    SettingsView()
                }
            case .folderRename:
                NavigationView {
                    FolderRenameView(selectedFeed)
                }
            case .feedSettings:
                NavigationView {
                    FeedSettingsView(selectedFeed)
                }
            case .login:
                NavigationView {
                    SettingsView()
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
