//
//  PageView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import SwiftUI

struct PageView<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Hashable, Content: View {
    @ObservedObject var webViewManager = WebViewManager(type: .article)
    @Binding var currentIndex: Int
    @State private var currentModel: ArticleModel?
    @GestureState private var translation: CGFloat = 0

    private let data: Data
    private let content: (ArticleModel) -> Content

    init(_ data: Data, currentIndex: Binding<Int>, @ViewBuilder content: @escaping (ArticleModel) -> Content) {
        self.data = data
        _currentIndex = currentIndex
        self.content = content
        if let item = data.first as? CDItem {
            currentModel = ArticleModel(item: item)
        }
        if let models = data as? [ArticleModel] {
            currentModel = models[currentIndex.wrappedValue]
            webViewManager.resetWebView()
            currentModel?.webView = webViewManager.webView
            currentModel?.isShowingData = true
        }
    }

    var body: some View {
        GeometryReader { geometry in
            LazyHStack(spacing: 0) {
                if let articleModels = data as? [ArticleModel] {
                    ForEach(articleModels) { elem in
                        content(elem)
                            .frame(width: geometry.size.width)
                    }
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .offset(x: -CGFloat(currentIndex) * geometry.size.width)
            .offset(x: translation)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .animation(.interactiveSpring())
            .gesture(
                DragGesture()
                    .updating($translation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        // determine how much was the page swiped to decide if the current page
                        // should change (and if it's going to be to the left or right)
                        // 1.25 is the parameter that defines how much does the user need to swipe
                        // for the page to change. 1.0 would require swiping all the way to the edge
                        // of the screen to change the page.
                        let offset = value.translation.width / geometry.size.width * 1.25
                        //                    let newIndex = (CGFloat(currentIndex) - offset).rounded()
                        //                    currentIndex = min(max(Int32(newIndex), 0), Int32(data.count - 1))
                        let newIndex = (CGFloat(currentIndex) - offset).rounded()
                        currentIndex = min(max(Int(newIndex), 0), data.count - 1)
                    }
            )
            .onChange(of: currentIndex) { newValue in
                print("Selected Index \(newValue)")
                currentModel?.isShowingData = false
                webViewManager.webView.stopLoading()
                if let models = data as? [ArticleModel] {
                    let currentModel = models[newValue]
                    if let existingWebView = currentModel.webView {
                        webViewManager.webView = existingWebView
                    } else {
                        webViewManager.resetWebView()
                        currentModel.webView = webViewManager.webView
                    }
                    currentModel.isShowingData = true
                }
            }
        }
    }
}

//struct PageView_Previews: PreviewProvider {
//    static var previews: some View {
//        PageView()
//    }
//}
