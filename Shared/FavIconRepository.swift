//
//  FavIconRepository.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/30/22.
//

import Combine
import Foundation

struct NodeIcon: Equatable {
    var nodeType: NodeType
    var icon: SystemImage
}

@MainActor
class FavIconRepository: NSObject, ObservableObject {
    var icons = CurrentValueSubject<[NodeType: String], Never>([:])

    private let favIconValidator = FavIconValidator()
    private let syncPublisher = NotificationCenter.default.publisher(for: .syncComplete, object: nil).eraseToAnyPublisher()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        syncPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    do {
                        try await self?.favIconValidator.fetch()
                    } catch { }
                }
                self?.update()
            }
            .store(in: &cancellables)
        icons.value[.all] = "rss"
        icons.value[.starred] = "star.fill"
        update()
    }

    private func update() {
        if let folders = CDFolder.all() {
            for folder in folders {
                Task {
                    self.icons.value[.folder(id: folder.id)] = "folder"
                }
            }
        }
        if let feeds = CDFeed.all() {
            for feed in feeds {
                icons.value[.feed(id: feed.id)] = feed.faviconLinkResolved
            }
        }
    }
}
