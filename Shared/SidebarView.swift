//
//  SidebarView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct SidebarView: View {
    @AppStorage(SettingKeys.selectedCategory) private var selection: String?
    @ObservedObject var model = FeedTreeModel()

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
                        //
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            })
            .listStyle(.sidebar)
            .refreshable {
                //TODO
            }
            .navigationTitle(Text("Feeds"))
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
    }
}
