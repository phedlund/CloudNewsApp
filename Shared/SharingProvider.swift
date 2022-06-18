//
//  SharingProvider.swift
//  iOCNews
//
//  Created by Peter Hedlund on 3/24/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftUI

#if os(macOS)
import AppKit

extension NSSharingService {
    private static let items = NSSharingService.sharingServices(forItems: [""])
    static func submenu(text: String) -> some View {
        return Menu(
            content: {
                ForEach(items, id: \.title) { item in
                    Button {
                        item.perform(withItems: [text])
                    } label: {
                        Label {
                            Text(item.title)
                        } icon: {
                            Image(nsImage: item.image)
                        }
                        .labelStyle(.titleAndIcon)

                    }
                }
                Button {
                    NSWorkspace.shared.open(URL(string: text) ?? URL(string: "data:null")!)
                } label: {
                    Label {
                        Text("Open in Browser")
                    } icon: {
                        Image(systemName: "safari")
                    }
                    .labelStyle(.titleAndIcon)
                }
            },
            label: {
                Image(systemName: "square.and.arrow.up")
            }
        )
        .menuStyle(.borderedButton)
    }
}

#else

import UIKit

class SharingProvider: UIActivityItemProvider {

    private var subject = ""

    init(placeholderItem: Any, subject: String) {
        super.init(placeholderItem: placeholderItem)
        self.subject = subject
    }

    override var item: Any {
        self.placeholderItem as Any
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        if activityType == .mail {
            return subject
        }
        return ""
    }

}
#endif
