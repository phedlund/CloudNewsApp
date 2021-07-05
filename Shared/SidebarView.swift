//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct SidebarView: View {
    @AppStorage(StorageKeys.selectedCategory) private var selection: String?
    @ObservedObject var model = FeedTreeModel()
    @State var isShowingLogin = false

    var body: some View {
        VStack {
            List(selection: $selection) {
                OutlineGroup(model.feedTree, children: \.children) { item in
                    HStack {
                        item.value.faviconImage
                        NavigationLink(destination: ItemsView(node: item.value)) {
                            Text(item.value.title)
                                .lineLimit(1)
                                .font(.subheadline)
                            Spacer()
                        }
                        Text(item.value.unreadCount ?? "")
                            .font(.subheadline)
                            .colorInvert()
                            .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                            .background(Capsule().fill(.gray))
                    }
                }
            }
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        async {
                            do {
                                try await NewsManager().sync()
                                model.update()
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
                        isShowingLogin = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            })
            .listStyle(.sidebar)
            .refreshable {
                do {
                    try await NewsManager().sync()
                    model.update()
                } catch {
                    //
                }
            }
            .navigationTitle(Text("Feeds"))
            .sheet(isPresented: $isShowingLogin, onDismiss: {
                isShowingLogin = false
            }, content: {
                NavigationView(content: {
                    LoginView(showModal: $isShowingLogin)
//                    SettingsView(showModal: $showModalSheet)
//                        .environmentObject(preferences)
//                        .environmentObject(sessionManager)
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
