//
//  FolderDisclosureGroup.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/16/21.
//

import CoreData
import SwiftUI

struct FolderDisclosureGroup<Label: View, Content: View> : View {
    @ObservedObject var node: Node

    @State private var isExpanded: Bool

    let content: Content
    let label: Label

    init(_ node: Node, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {
        self.node = node
        self.content = content()
        self.label = label()
        self._isExpanded = State(initialValue: node.isExpanded)
    }

    var body: some View {
        DisclosureGroup<Label, Content>(isExpanded: $isExpanded) {
            content
        } label: {
            label
        }
        .accentColor(.pbh.whiteIcon)
        .onChange(of: isExpanded) { newExpanded in
            print("Expanded: \(isExpanded)")
            switch node.nodeType {
            case .folder(let id):
                Task {
                    try? await CDFolder.markExpanded(folderId: id, state: newExpanded)
                }
            default:
                break
            }
        }
    }

}
