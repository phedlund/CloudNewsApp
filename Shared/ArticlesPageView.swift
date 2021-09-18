//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI
import WebKit

class ArticleModel: ObservableObject {
    var item: CDItem
    @Published var isShowingData: Bool

    init(item: CDItem, isShowingData: Bool = false) {
        self.item = item
        self.isShowingData = isShowingData
    }
}

struct ArticlesPageView: View {
    var items: FetchedResults<CDItem>
    @State var selectedIndex: Int32

    private var articleViews = [ArticleView]()
    @State var currentArticleView: ArticleView?

    init(items: FetchedResults<CDItem>, selectedIndex: Int32) {
        self.items = items
        _selectedIndex = State(initialValue: selectedIndex)
        for item in items {
            articleViews.append(ArticleView(articleModel: ArticleModel(item: item)))
        }
        if let newArticleView = articleViews.first(where: { $0.articleModel.item.id == selectedIndex }) {
            currentArticleView = newArticleView
            newArticleView.articleModel.isShowingData = true
        }
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(items.indices) { index in
                let articleView = articleViews[index]
                articleView
                    .tag(items[index].id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: selectedIndex) { newValue in
            print("Selected Index \(newValue)")
            currentArticleView?.articleModel.isShowingData = false
            if let newArticleView = articleViews.first(where: { $0.articleModel.item.id == newValue }) {
                currentArticleView = newArticleView
                newArticleView.articleModel.isShowingData = true
            }
        }
    }
}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
