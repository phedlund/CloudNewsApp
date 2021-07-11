//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct SidebarView: View {
    @AppStorage(StorageKeys.selectedCategory) private var selection: String?
    @EnvironmentObject var nodeTree: FeedTreeModel
    @State private var isShowingSettings = false

    var body: some View {
        VStack {
            List(selection: $selection) {
                OutlineGroup(nodeTree.feedTree.children ?? [], children: \.children) { item in
                    NodeView(node: item)
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
                        isShowingSettings = true
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
            .sheet(isPresented: $isShowingSettings, onDismiss: {
                isShowingSettings = false
            }, content: {
                NavigationView(content: {
                    SettingsView(showModal: $isShowingSettings)
                })
            })

        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
    }
}
