//
//  HelperViews.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/9/22.
//

import Combine
import Foundation
import SwiftUI

struct OptionalNavigationStack<Content: View>: View {
    let content: Content
    let path: Binding<NavigationPath>

    init(path: Binding<NavigationPath>, @ViewBuilder content: @escaping () -> Content) {
        self.path = path
        self.content = content()
    }

    var body: some View {
#if os(iOS)
        NavigationStack(path: path) {
            content
        }
#else
        content
#endif
    }

}

struct SingleItemView<Content: View>: View {
    let content: Content
    let model: ArticleModel

    init(model: ArticleModel, @ViewBuilder content: @escaping () -> Content) {
        self.model = model
        self.content = content()
    }

    var body: some View {
#if os(iOS)
        NavigationLink(value: model) {
            HStack {
                Spacer()
                content
                Spacer()
            }
        }
#else
        content
#endif
    }

}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content {
        build()
    }
}

class ScrollViewHelper: ObservableObject {
    @Published var currentOffset: CGFloat = 0
    @Published var offsetAtScrollEnd: CGFloat = 0

    private var cancellable: AnyCancellable?

    init() {
        cancellable = AnyCancellable($currentOffset
            .debounce(for: 0.2, scheduler: DispatchQueue.main)
            .dropFirst()
            .assign(to: \.offsetAtScrollEnd, on: self))
    }

}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct ClearSelectionStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background(Color.clear)
    }
}

