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
    @Published public var feedIcon = SystemImage()
    @Published public var dateAuthorFeed = ""
    @Published public var displayBody = ""

    public var webViewHelper = ItemWebViewHelper()

    private var cancellables = Set<AnyCancellable>()

    init(item: CDItem) {
        self.item = item
        super.init()
        item
            .publisher(for: \.imageLink)
            .receive(on: DispatchQueue.main)
            .sink {
                if let imageLink = $0, !imageLink.isEmpty, imageLink != "data:null", let url = URL(string: imageLink) {
                    self.imageURL = url
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
            .sink { newId in
                if let data = CDFeed.feed(id: newId)?.favicon {
                    self.feedIcon = SystemImage(data: data) ?? SystemImage()
                } else {
                    self.feedIcon = SystemImage(named: "rss") ?? SystemImage()
                }
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
        item
            .publisher(for: \.title)
            .receive(on: DispatchQueue.main)
            .sink {
                self.title = $0
            }
            .store(in: &cancellables)
    }

}
