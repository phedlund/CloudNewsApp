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

    private let clipLength = 50

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
            .publisher(for: \.pubDate)
            .receive(on: DispatchQueue.main)
            .sink {
                var dateLabelText = ""
                let date = Date(timeIntervalSince1970: TimeInterval($0))
                dateLabelText.append(DateFormatter.dateAuthorFormatter.string(from: date))

                if !dateLabelText.isEmpty {
                    dateLabelText.append(" | ")
                }

                if let itemAuthor = item.author, !itemAuthor.isEmpty {
                    if itemAuthor.count > self.clipLength {
                        dateLabelText.append(contentsOf: itemAuthor.filter( { !$0.isNewline }).prefix(self.clipLength))
                        dateLabelText.append(String(0x2026))
                    } else {
                        dateLabelText.append(itemAuthor)
                    }
                }

                if let feedTitle = CDFeed.feed(id: item.feedId)?.title {
                    if let itemAuthor = item.author, !itemAuthor.isEmpty {
                        if feedTitle != itemAuthor {
                            dateLabelText.append(" | \(feedTitle)")
                        }
                    } else {
                        dateLabelText.append(feedTitle)
                    }
                }
                self.dateAuthorFeed = dateLabelText
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
