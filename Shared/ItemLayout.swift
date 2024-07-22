//
//  ItemLayout.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/8/24.
//

import SwiftUI

struct ItemLayout: Layout {
    let cellSize: CGSize

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//        thumbnailView
//        titleView
//        favIconDateAuthorView
//        bodyView

        for (index, subview) in subviews.enumerated() {
            let viewSize = subview.sizeThatFits(.unspecified)

            switch index {
            case 0:
                subview.place(at: .zero, anchor: .topLeading, proposal: ProposedViewSize(width: .defaultThumbnailWidth, height: cellSize.height))
            case 1:
                subview.place(at: CGPoint(x: .defaultThumbnailWidth, y: 0), anchor: .topLeading, proposal: ProposedViewSize(width: cellSize.width - .defaultThumbnailWidth, height: 20))
            case 2:
                subview.place(at: CGPoint(x: .defaultThumbnailWidth, y: 24), anchor: .topLeading, proposal: ProposedViewSize(width: cellSize.width - .defaultThumbnailWidth, height: 10))
            case 3:
                subview.place(at: CGPoint(x: .defaultThumbnailWidth, y: 50), anchor: .topLeading, proposal: ProposedViewSize(width: cellSize.width - .defaultThumbnailWidth, height: cellSize.height - 30))
            default:
                subview.place(at: .zero, anchor: .center, proposal: ProposedViewSize(width: .defaultThumbnailWidth, height: .defaultCellHeight))
            }

//            // ask this view for its ideal size
//            let viewSize = subview.sizeThatFits(ProposedViewSize(width: <#T##CGFloat?#>, height: <#T##CGFloat?#>))
//
//            // calculate the X and Y position so this view lies inside our circle's edge
//            let xPos = cos(angle * Double(index) - .pi / 2) * (radius - viewSize.width / 2)
//            let yPos = sin(angle * Double(index) - .pi / 2) * (radius - viewSize.height / 2)
//
//            // position this view relative to our centre, using its natural size ("unspecified")
//            let point = CGPoint(x: bounds.midX + xPos, y: bounds.midY + yPos)
//            subview.place(at: point, anchor: .center, proposal: .unspecified)
        }

    }
    
}

