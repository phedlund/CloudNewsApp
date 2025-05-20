//
//  UtilitiesShared.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/6/25.
//

import Foundation
import SwiftSoup

#if os(macOS)
import AppKit
public typealias SystemImage = NSImage
#else
import UIKit
public typealias SystemImage = UIImage
#endif

extension DateFormatter {
    static var dateAuthorFormatter: DateFormatter {
        let currentLocale = Locale.current
        let dateComponents = "MMM d"
        let dateFormatString = DateFormatter.dateFormat(fromTemplate: dateComponents, options: 0, locale: currentLocale)
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = dateFormatString
        return dateFormat
    }
}

func plainSummary(raw: String) -> String {
    guard let doc: Document = try? SwiftSoup.parse(raw) else {
        return raw
    } // parse html
    guard let txt = try? doc.text() else {
        return raw
    }
    return txt
}
