//
//  ItemSizeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/24.
//

import Foundation
import Observation
import SwiftUI

enum ItemLayoutView: Int {
    case thumbnail
    case title
    case favIconDateAuthor
    case body
}

struct LayoutViewType: LayoutValueKey {
    static let defaultValue: ItemLayoutView = .title
}

struct ViewCache {
    var sizes = [ItemLayoutView: CGSize]()
}

@Observable
class ItemSizeModel {

    var thumbnailOffset = CGFloat.defaultThumbnailWidth + .paddingSix
    var thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
    var noThumbnailSize = CGSize(width: .zero, height: .defaultCellHeight)

    func update(_ isCompactView: Bool, _ showThumbnails: Bool) {
        noThumbnailSize = CGSize(width: .zero, height: isCompactView ? .compactCellHeight : .defaultCellHeight)

        if !showThumbnails {
            thumbnailOffset = .zero
            thumbnailSize = noThumbnailSize
        } else {
            if isCompactView {
                thumbnailOffset = .compactThumbnailWidth + .paddingSix
                thumbnailSize = CGSize(width: .compactThumbnailWidth, height: .compactCellHeight)
            } else {
                thumbnailOffset = .defaultThumbnailWidth + .paddingSix
                thumbnailSize = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
            }
        }
    }

}

struct RegularWithThumbnail: Layout {

    let cellSize: CGSize

    func makeCache(subviews: Subviews) -> ViewCache {
        .init()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ViewCache) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        var height: CGFloat = .zero


        for i in subviews.indices {
            let subview = subviews[i]
            let subViewValue = subview[LayoutViewType.self]
            switch subViewValue {
            case .thumbnail:
                cache.sizes[.thumbnail] = CGSize(width: .defaultThumbnailWidth, height: .defaultCellHeight)
            case .title:
                let mySize = subview.sizeThatFits(ProposedViewSize(width: cellSize.width - (.paddingSix + .defaultThumbnailWidth), height: proposal.height))
                let viewDimension = subview.dimensions(in: ProposedViewSize(width: cellSize.width - (.paddingSix + .defaultThumbnailWidth), height: proposal.height))
                cache.sizes[.title] = mySize
            case .favIconDateAuthor:
                let mySize = subview.sizeThatFits(ProposedViewSize(width: cellSize.width - (.paddingSix + .defaultThumbnailWidth), height: 22.0))
                cache.sizes[.favIconDateAuthor] = mySize
            case .body:
                let mySize = subview.sizeThatFits(ProposedViewSize(width: cellSize.width - (.paddingSix + .defaultThumbnailWidth), height: proposal.height))
                cache.sizes[.body] = mySize
            }
//            if subview[ActiveKey.self] == true {
//                cache.activeIndex = i
//            }
//            let viewDimension = subview.dimensions(in: proposal)
//            cache.sizes.append(.init(width: viewDimension.width, height: viewDimension.height))
        }
        return cellSize
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ViewCache) {
        guard !subviews.isEmpty else { return }
        let cellX = (bounds.width - cellSize.width) / 2
        var currentY: CGFloat = bounds.minY

        for i in subviews.indices {
            let subview = subviews[i]
            let subViewValue = subview[LayoutViewType.self]
            switch subViewValue {
            case .thumbnail:
                subview.place(at: .init(x: bounds.minX + cellX, y: currentY), anchor: .topLeading, proposal: proposal)
            case .title:
                subview.place(at: .init(x: bounds.minX + cellX + .paddingSix + .defaultThumbnailWidth, y: currentY), anchor: .topLeading, proposal: proposal)
                currentY += cache.sizes[.title]?.height ?? 0.0
            case .favIconDateAuthor:
                subview.place(at: .init(x: bounds.minX + cellX + .paddingSix + .defaultThumbnailWidth, y: currentY), anchor: .topLeading, proposal: proposal)
                currentY += cache.sizes[.favIconDateAuthor]?.height ?? 0.0
            case .body:
                subview.place(at: .init(x: bounds.minX + cellX + .paddingSix + .defaultThumbnailWidth, y: currentY), anchor: .topLeading, proposal: proposal)
            }
        }
    }

}
