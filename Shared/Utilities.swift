//
//  Utilities.swift
//  Utilities
//
//  Created by Peter Hedlund on 9/6/21.
//

//import UIKit

#if os(macOS)
import AppKit
public typealias SystemImage = NSImage
public typealias SystemView = NSView
public typealias SystemColor = NSColor
public typealias SystemImageView = NSImageView
public typealias SystemButton = NSButton
#else
import UIKit
public typealias SystemImage = UIImage
public typealias SystemView = UIView
public typealias SystemColor = UIColor
public typealias SystemImageView = UIImageView
public typealias SystemButton = UIButton
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

extension TimeInterval {
    static let fiveMinutes: TimeInterval = 300
}

extension CGFloat {
    static let defaultCellHeight: CGFloat = 160.0
    static let compactCellHeight: CGFloat = 85.0
    static let defaultThumbnailWidth: CGFloat = 145.0
    static let compactThumbnailWidth: CGFloat = 66.0
}

extension URL {

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

    func asPngData() -> Data? {
#if os(macOS)
        return self.png
#else
        return self.pngData()
#endif
    }
}

#if os(macOS)
extension NSBitmapImageRep {
    var png: Data? { representation(using: .png, properties: [:]) }
}
extension Data {
    var bitmap: NSBitmapImageRep? { NSBitmapImageRep(data: self) }
}
extension NSImage {
    var png: Data? { tiffRepresentation?.bitmap?.png }
}
#endif

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
        if let index = self.firstIndex(of: element){
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
