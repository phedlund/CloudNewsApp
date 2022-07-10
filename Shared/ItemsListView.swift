//
//  ItemsListView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/22.
//

import SwiftUI

struct ItemsListView: View {
    @EnvironmentObject private var settings: Preferences
    @ObservedObject var node: Node
    var cellWidth: CGFloat
    var viewHeight: CGFloat

    @StateObject private var scrollViewHelper = ScrollViewHelper()
    @State private var cellHeight: CGFloat = 160.0

    var body: some View {
        ForEach(node.items, id: \.id) { item in
            SingleItemView(model: item) {
                ItemListItemViev(model: item)
                    .tag(item.id)
                    .frame(width: cellWidth, height: cellHeight, alignment: .center)
                    .listRowBackground(Color.pbh.whiteBackground)
                    .contextMenu {
                        ContextMenuContent(model: item)
                    }
                    .transformAnchorPreference(key: ViewOffsetKey.self, value: .top) { prefKey, _ in
                        if let index = node.items.firstIndex(of: item) {
                            prefKey = CGFloat(index)
                        }
                    }
                    .onPreferenceChange(ViewOffsetKey.self) {
                        let offset = ($0 * (cellHeight + 15)) - viewHeight
                        scrollViewHelper.currentOffset = offset
                    }
            }
        }
        .listRowBackground(Color.pbh.whiteBackground)
        .listRowSeparator(.hidden)
        .navigationTitle(node.title)
        .onReceive(settings.$compactView) { cellHeight = $0 ? 85.0 : 160.0 }
    }
}

//struct ItemsListView_Previews: PreviewProvider {
//    static var previews: some View {
//        ItemsListView()
//    }
//}
