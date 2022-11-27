//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Combine
import Foundation

class ArticleModel: NSObject, ObservableObject, Identifiable {
    var item: CDItem
    @Published public var title = ""
    @Published public var imageURL: URL?
    @Published public var unread = true
    @Published public var starred = false
    @Published public var feed: CDFeed?
    @Published public var dateAuthorFeed = ""
    @Published public var displayBody = ""

    public var webViewHelper = ItemWebViewHelper()

    private var cancellables = Set<AnyCancellable>()

    init(item: CDItem) {
        self.item = item
//        feed = CDFeed.feed(id: item.feedId)
        super.init()

        item
            .publisher(for: \.displayTitle)
            .receive(on: DispatchQueue.main)
            .sink {
                self.title = $0
            }
            .store(in: &cancellables)
        item
            .publisher(for: \.imageUrl)
            .receive(on: DispatchQueue.main)
            .sink {
                self.imageURL = $0 as URL?
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
                self.feed = CDFeed.feed(id: $0)
            }
            .store(in: &cancellables)
        item
            .publisher(for: \.dateFeedAuthor)
            .receive(on: DispatchQueue.main)
            .sink {
                self.dateAuthorFeed = $0
            }
            .store(in: &cancellables)
        item
            .publisher(for: \.displayBody)
            .receive(on: DispatchQueue.main)
            .sink {
                self.displayBody = $0
            }
            .store(in: &cancellables)
    }

}
