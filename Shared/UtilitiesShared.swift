//
//  UtilitiesShared.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/6/25.
//

import Foundation
import OSLog
import SwiftSoup

#if os(macOS)
import AppKit
public typealias SystemImage = NSImage
#else
import UIKit
public typealias SystemImage = UIImage
#endif

@MainActor
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

@MainActor
func plainSummary(raw: String) -> String {
    guard let doc: Document = try? SwiftSoup.parse(raw) else {
        return raw
    } // parse html
    guard let txt = try? doc.text() else {
        return raw
    }
    return txt
}

extension Logger {
    nonisolated(unsafe) private static var subsystem = Bundle.main.bundleIdentifier!

    static let app = Logger(subsystem: subsystem, category: "app")
}
