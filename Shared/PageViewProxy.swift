//
//  PageViewProxy.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/27/24.
//

import Foundation
import SwiftUI
import WebKit

@Observable
class PageViewProxy {
    var scrollId: Int64?
    var page: WebPage
    var itemId: Int64?

    init(page: WebPage, scrollId: Int64? = nil, itemId: Int64? = nil) {
        self.page = page
        self.scrollId = scrollId
        self.itemId = itemId
    }
}
