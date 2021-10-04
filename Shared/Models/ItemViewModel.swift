//
//  ItemViewModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/3/21.
//

import Combine
import Foundation

class ItemViewModel: ObservableObject {
    @Published var items = [CDItem]()

    private var cancellable = Set<AnyCancellable>()

    init(itemPublisher: AnyPublisher<[CDItem], Never> = ItemStorage.shared.items.eraseToAnyPublisher()) {
        itemPublisher.sink { items in
            print("Updating Items")
            self.items = items
        }
        .store(in: &cancellable)
    }

    func nodeItems(_ nodeType: NodeType) -> [CDItem] {
        switch nodeType {
        case .all:
            return items
        case .starred:
            return items.filter({ $0.starred == true })
        case .folder(let id):
            if let feedIds = CDFeed.idsInFolder(folder: id) {
                return items.filter({ feedIds.contains($0.feedId) })
            }
        case .feed(let id):
            return items.filter({ $0.feedId == id })
        }
        return []
    }

}
