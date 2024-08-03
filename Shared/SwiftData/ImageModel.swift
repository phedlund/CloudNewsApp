//
//  Image.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/3/24.
//

import Foundation
import SwiftData

@Model
final class ImageModel {
    @Attribute(.unique) var id: Int64
    @Attribute(.externalStorage) var pngData: Data? = nil

    init(id: Int64, pngData: Data) {
        self.id = id
        self.pngData = pngData
    }
}

#if canImport(AppKit)
//import AppKit
//
///// Initialize the image model from an `NSImage`.
/////
///// - Parameters:
/////   - type: The type of the image the image model represents.
/////   - image: The `NSImage` to store in the image model.
/////
//    convenience init(type: ImageType, image: NSImage) throws {
//        guard let pngData = image.pngData() else {
//            throw GenericError.failed("Unable to get PNG data for image")
//        }
//
//        self.init(type: type, pngData: pngData)
//    }

#elseif canImport(UIKit)
import UIKit

extension ImageModel {
    convenience init(id: Int64, image: UIImage) throws {
        guard let pngData = image.pngData() else {
            throw DatabaseError.generic(message: "Unable to get PNG data for image")
        }

        self.init(id: id, pngData: pngData)
    }

}
#endif

#if canImport(UIKit)
import UIKit

extension UIImage {
    convenience init?(loadingDataFrom model: ImageModel) {
        guard let data = model.pngData,
              data.isEmpty == false
        else {
            return nil
        }

        self.init(data: data)
    }
}

#elseif canImport(AppKit)
import AppKit

extension NSImage {
/// Initialize a new `NSImage` using data from an `ImageModel`.
///
/// - Parameters:
///   - model: The image model to load the image from.
///
    convenience init?(loadingDataFrom model: ImageModel) {
        guard let data = model.pngData,
              data.isEmpty == false
        else {
            return nil
        }

        self.init(data: data)
    }
}
#endif
