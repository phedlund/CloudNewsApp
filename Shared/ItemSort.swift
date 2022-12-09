//
//  ItemSort.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/28/22.
//

import Foundation

struct ItemSort: Hashable, Identifiable {
    let id: Int
    let name: String
    let descriptors: [SortDescriptor<CDItem>]

    static let sorts: [ItemSort] = [
        ItemSort(
        id: 0,
        name: "Newest First",
        descriptors: [
          SortDescriptor(\CDItem.id, order: .reverse),
        ]),
        ItemSort(
        id: 1,
        name: "Oldest First",
        descriptors: [
            SortDescriptor(\CDItem.id, order: .forward),
        ])
    ]

    // 4
    static var `default`: ItemSort { sorts[0] }




}
