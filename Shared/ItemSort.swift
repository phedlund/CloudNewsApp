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
    let descriptors: [SortDescriptor<Item>]

    static let sorts: [ItemSort] = [
        ItemSort(
        id: 0,
        name: "Newest First",
        descriptors: [
          SortDescriptor(\Item.id, order: .reverse),
        ]),
        ItemSort(
        id: 1,
        name: "Oldest First",
        descriptors: [
            SortDescriptor(\Item.id, order: .forward),
        ])
    ]

    static var `default`: ItemSort { sorts[0] }
    static var `oldestFirst`: ItemSort { sorts[1] }

}
