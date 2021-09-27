//
//  ItemImageView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/26/21.
//

import Kingfisher
import SwiftUI

struct ItemImageView: View {
    @AppStorage(StorageKeys.compactView) private var compactView: Bool?
    @AppStorage(StorageKeys.showThumbnails) private var showThumbnails: Bool?

    var item: CDItem

    @ViewBuilder
    var body: some View {
        let isCompactView = compactView ?? false
        let isShowingThumbnails = showThumbnails ?? true
        let cellHeight = isCompactView ? 84.0 : 160.0
        let cellWidth = isCompactView ? 66.0 : 145.0

        if isShowingThumbnails, let imageLink = item.imageLink, let thumbnailURL = URL(string: imageLink) {
            KFImage(thumbnailURL)
                .cancelOnDisappear(true)
                .setProcessors([ResizingImageProcessor(referenceSize: CGSize(width: cellWidth, height: cellHeight), mode: .aspectFill),
                                CroppingImageProcessor(size: CGSize(width: cellWidth, height: cellHeight), anchor: CGPoint(x: 0.5, y: 0.5)),
                                OverlayImageProcessor(overlay: .white, fraction: item.unread ? 1.0 : 0.4)])
        } else {
            Spacer(minLength: 2)
        }
    }
}

