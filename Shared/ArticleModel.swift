//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Foundation
import WebKit

class ArticleModel: ObservableObject, Identifiable {
    var item: CDItem
    var webView: WKWebView?
    @Published var isShowingData: Bool

    init(item: CDItem, isShowingData: Bool = false) {
        self.item = item
        self.isShowingData = isShowingData
    }
}

extension ArticleModel: Hashable {

    static func == (lhs: ArticleModel, rhs: ArticleModel) -> Bool {
        return lhs.item.id == rhs.item.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(item.id)
    }

}
