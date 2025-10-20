//
//  ImageUtils.swift
//  CloudNews
//

import UIKit

enum ImageUtils {
    nonisolated static func decompressImage(data: Data) -> UIImage? {
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        let rect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)
        
        guard let decompressedCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: decompressedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
