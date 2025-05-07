//
//  Utilities.swift
//  Utilities
//
//  Created by Peter Hedlund on 9/6/21.
//

import SwiftSoup

#if os(macOS)
import AppKit
public typealias SystemImage = NSImage
public typealias SystemColor = NSColor
#else
import UIKit
public typealias SystemImage = UIImage
public typealias SystemColor = UIColor
#endif

extension TimeInterval {
    static let fifteenMinutes: TimeInterval = 900
}

extension CGFloat {
    static let defaultCellHeight: CGFloat = 160.0
    static let compactCellHeight: CGFloat = 85.0
    static let defaultThumbnailWidth: CGFloat = 145.0
    static let compactThumbnailWidth: CGFloat = 66.0
    static let paddingSix: CGFloat = 6.0
    static let paddingEight: CGFloat = 8.0
}

extension URL {

    @MainActor
    init?(withCheck string: String?) {
        let regEx = "((https|http)://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
#if os(macOS)
        guard
            let urlString = string,
            let url = URL(string: urlString),
            NSPredicate(format: "SELF MATCHES %@", argumentArray: [regEx]).evaluate(with: urlString)
        else {
            return nil
        }
        self = url
#else
        guard
            let urlString = string,
            let url = URL(string: urlString),
            NSPredicate(format: "SELF MATCHES %@", argumentArray: [regEx]).evaluate(with: urlString),
            UIApplication.shared.canOpenURL(url)
        else {
            return nil
        }
        self = url
#endif
    }
}

extension SystemImage {
    convenience init?(symbolName: String) {
#if os(macOS)
        self.init(systemSymbolName: symbolName, accessibilityDescription: nil)
#else
        self.init(systemName: symbolName)
#endif
    }
}

func tempDirectory() -> URL? {
    let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("CloudNews", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        return nil
    }
    return tempDirURL
}

extension Collection where Element: Equatable {

    func element(after element: Element, wrapping: Bool = false) -> Element? {
        if let index = self.firstIndex(of: element){
            let followingIndex = self.index(after: index)
            if followingIndex < self.endIndex {
                return self[followingIndex]
            } else if wrapping {
                return self[self.startIndex]
            }
        }
        return nil
    }
}

extension BidirectionalCollection where Element: Equatable {

    func element(before element: Element, wrapping: Bool = false) -> Element? {
        if let index = self.firstIndex(of: element) {
            let precedingIndex = self.index(before: index)
            if precedingIndex >= self.startIndex {
                return self[precedingIndex]
            } else if wrapping {
                return self[self.index(before: self.endIndex)]
            }
        }
        return nil
    }
}

