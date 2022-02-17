//
//  ItemListItemViewContainer.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/12/22.
//

import SwiftUI

struct ItemListItemViewContainer: View {
    @State var item: CDItem
    let items: Node
    let node: Node
    let cellHeight: CGFloat
    let cellWidth: CGFloat

    @Binding var fullScreenView: Bool
    @Binding var selectedIndex: Int

    @ViewBuilder
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationLink(destination: NavigationLazyView(ArticlesPageView(node: node, fullScreenView: .constant(false)))) {
                ItemListItemViev(item: item)
                    .tag(selectedIndex)
                    .frame(width: cellWidth, height: cellHeight, alignment: .center)

                    .buttonStyle(.plain)
                    .contextMenu {
                        ContextMenuContent(item: item)
                    }
            }
        } else {
            ItemListItemViev(item: item)
                .tag(selectedIndex)
                .frame(width: cellWidth, height: cellHeight, alignment: .center)
                .buttonStyle(.plain)
                .onTapGesture {
                    node.selectedItem = selectedIndex
                    fullScreenView = true
                }
                .contextMenu {
                    ContextMenuContent(item: item)
                }
                .fullScreenCover(isPresented: $fullScreenView) {
                    //
                } content: {
                    NavigationView {
                        ArticlesPageView(node: node, fullScreenView: $fullScreenView)
                    }
                }
        }
    }

}

struct NavigationLazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}
