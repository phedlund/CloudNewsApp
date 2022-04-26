//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View, Equatable {
    static func == (lhs: ArticleView, rhs: ArticleView) -> Bool {
        return lhs.model == rhs.model
    }

    @ObservedObject var model: ArticleModel

    var body: some View {
        ArticleWebView(model: model)
            .equatable()
            .navigationBarTitleDisplayMode(.inline)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
    }
    
}

struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    public var body: some View {
        content($value)
    }

    public init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        self._value = State(wrappedValue: value)
        self.content = content
    }
}

//struct ArticleView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticleWebView(webView: WebViewManager(type: .article).webView)
//    }
//}

extension UINavigationController {

  open override func viewWillLayoutSubviews() {
    navigationBar.topItem?.backButtonDisplayMode = .minimal
  }

}
