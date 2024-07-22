//
//  ItemSizeModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/24.
//

import Foundation
import Observation

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
