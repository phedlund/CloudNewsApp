//
//  ItemsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI

struct ItemsView: View {
    var node: AnyTreeNode
    
    var body: some View {
        VStack {
            List {
                ForEach(node.items, id: \.self.id) { item in
                    // Workaround to hide disclosure indicator
                    ZStack(alignment: .center) {
                        NavigationLink(destination: ArticleView(item: item)) {
                            EmptyView()
                        }
                        .opacity(0)
                        ItemListItemViev(item: item)
                            .frame(minWidth: 300,
                                   idealWidth: 700,
                                   maxWidth: 700,
                                   minHeight: 85,
                                   idealHeight: 160,
                                   maxHeight: 160,
                                   alignment: .center)
                    }
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color(.clear)) // disable selection highlight
            }
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        //
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            })
            .listStyle(.plain)
            .navigationTitle(node.title)
        }
    }
}

struct ItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ItemsView(node: AnyTreeNode(StarredFeedNode()))
    }
}
