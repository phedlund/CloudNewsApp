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
    case folders
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

    private var publisher = NotificationCenter.default
        .publisher(for: .syncComplete)
        .receive(on: DispatchQueue.main)

    var body: some View {
        List(selection: $selectedNode) {
            OutlineGroup(model.nodes, children: \.children) { node in
                NodeView(node: node, selectedFeed: $selectedFeed, modalSheet: $modalSheet, isShowingSheet: $isShowingSheet, model: model) {
                    ItemsView(node: node)
                        .environmentObject(model)
                }
                .tag(node.id)
            }
            .accentColor(.pbh.whiteIcon)
        }
        .listStyle(.sidebar)
        .accentColor(.pbh.darkIcon)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .opacity(isSyncing ? 1.0 : 0.0)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        do {
                            isSyncing = true
                            try await NewsManager().sync()
                            model.update()
                        } catch {
                            isSyncing = false
                        }
                    }
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
        .onChange(of: selectedNode) {
            print($0 ?? "")
        }
        .refreshable {
            do {
                try await NewsManager().sync()
                model.update()
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
                NavigationView {
                    SettingsView(showModal: $isShowingSheet)
                }
            case .folders:
                NavigationView {
                    SettingsView(showModal: $isShowingSheet)
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
