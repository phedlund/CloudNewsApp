//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @State private var isShowingData = false

    var articleModel: ArticleModel

    init(articleModel: ArticleModel) {
        self.articleModel = articleModel
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isShowingData {
                    ArticleWebView(webView: articleModel.webView!, item: articleModel.item, size: geometry.size)
                        .navigationTitle(articleModel.item.title ?? "Untitled")
                        .navigationBarTitleDisplayMode(.inline)
                        .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.3)))
                }
                else {
                    EmptyView()
//                    VStack {
//                        Spacer()
//                        Text(articleModel.item.title ?? "Untitled")
//                            .navigationTitle(articleModel.item.title ?? "Untitled")
//                            .navigationBarTitleDisplayMode(.inline)
//                        .frame(alignment: .center)
//                        Spacer()
//                    }
                }
            }
            .onAppear {
                delayMarkingRead()
            }
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onReceive(articleModel.$isShowingData, perform: { isShowingData in
                self.isShowingData = isShowingData
            })
        }
    }

    private func delayMarkingRead() {
        // The delay prevents the view from jumping back to the items list
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if articleModel.item.unread {
                Task {
                    try? await NewsManager.shared.markRead(items: [articleModel.item], unread: false)
                }
            }
        }
    }

}

struct PopoverView: View {
    var body: some View {
        Text("Popover Content")
            .padding()
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
