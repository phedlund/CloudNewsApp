//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Combine
import Foundation
import Nuke

class ArticleModel: NSObject, ObservableObject, Identifiable {
    @Published public var title = ""
    @Published public var imageLink: String?
    @Published public var unread = true
    @Published public var starred = false
    @Published public var feedId: Int32 = 0
    @Published public var dateAuthorFeed = ""
    @Published public var displayBody = ""

    public var webViewHelper = ItemWebViewHelper()

    private var cancellables = Set<AnyCancellable>()

    var item: CDItem?

    init(item: CDItem?) {
        self.item = item
        super.init()
        if let item = item {
            item
                .publisher(for: \.imageLink)
                .sink {
                    if let imageLink = $0, !imageLink.isEmpty, imageLink != "data:null" {
                        self.imageLink = imageLink
                    } else if let imageLink = $0, !imageLink.isEmpty, imageLink == "data:null" {
                        return
                    } else {
                        ItemImageFetcher().itemURL(item)
                    }
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.unread)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.unread = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.starred)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.starred = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.feedId)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.feedId = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.dateAuthorFeed)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.dateAuthorFeed = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.displayBody)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.displayBody = $0 ?? ""
                }
                .store(in: &cancellables)
            title = item.title ?? "Untitled"
        }
    }

}
