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
                ForEach(model.feedTree, id: \.self.id) { node in
                    if node.isLeaf {
                        NavigationLink(destination: ItemsView(node: node)) {
                            Label(node.title, systemImage: "doc")
                                .tag(node.id)
                        }
                    } else {
                        Section(header: Label(node.title, systemImage: "folder")) {
                            ForEach(node.children) { feed in
                                NavigationLink(destination: ItemsView(node: feed)) {
                                    Label(feed.title, systemImage: "doc")
                                        .tag(feed.id)
                                }
                            }
                        }
                    }
                }
            }
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
