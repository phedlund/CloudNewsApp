//
//  ContainerView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/15/23.
//

import SwiftUI

protocol ContainerView: View {
    associatedtype Content
    init(content: @escaping () -> Content)
}

extension ContainerView {
    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.init(content: content)
    }
}

struct ListGroup<Content: View>: ContainerView {
    @EnvironmentObject private var model: FeedModel

    var content: () -> Content

    var body: some View {
        Group {
#if os(macOS)
            VStack(content: content)
#else
            NavigationStack(path: $model.path, root: content)
#endif
        }
    }
}

struct RowContainer<Content: View>: ContainerView {
    var content: () -> Content

    var body: some View {
        Group {
#if os(macOS)
            Group(content: content)
#else
            HStack {
                Spacer()
                Group(content: content)
                Spacer()
            }
#endif
        }
    }
}

struct ZStackGroup<Content: View>: View {
    var item: CDItem
    var content: () -> Content

    var body: some View {
#if os(macOS)
        Group(content: content)
#else
        ZStack {
            NavigationLink(value: item) {
                EmptyView()
            }
            .opacity(0)
            Group(content: content)
        }
#endif
    }
}
