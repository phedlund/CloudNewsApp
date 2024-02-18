//
//  ScrollingSupport.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/16/24.
//

import Combine
import SwiftUI

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

extension View {
    func onScrollEnded(in coordinateSpace: CoordinateSpace, onScrollEnded: @escaping (CGFloat) -> Void) -> some View {
        modifier(OnVerticalScrollEnded(coordinateSpace: coordinateSpace, scrollPostionUpdate: onScrollEnded))
    }
}

final class OnVerticalScrollEndedOffsetTracker: ObservableObject {
    let scrollViewVerticalOffset = CurrentValueSubject<CGFloat, Never>(0)

    func updateOffset(_ offset: CGFloat) {
        scrollViewVerticalOffset.send(offset)
    }
}

struct OnVerticalScrollEnded: ViewModifier {
    let coordinateSpace: CoordinateSpace
    let scrollPostionUpdate: (CGFloat) -> Void
    @StateObject private var offsetTracker = OnVerticalScrollEndedOffsetTracker()

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader(content: { geometry in
                    Color.clear.preference(key: ViewOffsetKey.self, value: abs(geometry.frame(in: coordinateSpace).origin.y))
                })
            )
            .onPreferenceChange(ViewOffsetKey.self, perform: offsetTracker.updateOffset(_:))
            .onReceive(offsetTracker.scrollViewVerticalOffset.debounce(for: 0.1, scheduler: DispatchQueue.main).dropFirst(), perform: scrollPostionUpdate)
    }
}
