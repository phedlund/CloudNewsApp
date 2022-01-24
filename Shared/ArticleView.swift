//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    var articleModel: ArticleModel
    @State var frameHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                ArticleWebView(articleModel: articleModel)
                    .navigationBarTitleDisplayMode(.inline)
                    .background {
                        Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
                    }
                    .frame(width: geometry.size.width, height: max(geometry.size.height, frameHeight))
            }
        }
        .onReceive(articleModel.$contentHeight) { newHeight in
            print("Got new height \(newHeight)")
            if newHeight > 0 {
                frameHeight = newHeight
            }
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
