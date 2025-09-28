//
//  LoadImageError.swift
//  CloudNews
//
//  Created by Peter Hedlund on 9/27/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View>: View {

    enum LoadImageError: Error {
        case timeout
        case badRequest
        case loadImageFailed
    }
    
    var url: URL?
    var transaction: Transaction = Transaction()
    var compressedSize: CGSize = .init(width: 10, height: 8)
    var loadFullResolution: Bool = false
    @ViewBuilder var content: (AsyncImagePhase) -> Content
    
    @State private var uiImage: UIImage? = nil
    @State private var phase: AsyncImagePhase = .empty
    

    var body: some View {
        content(phase)
            .transaction { view in
                view.animation = self.transaction.animation
            }
            .onChange(of: url, initial: true) {
                Task {
                    await self.updateImage()
                }
            }
            .onChange(of: loadFullResolution, {
                Task {
                    await self.updateImage()
                }
            })
    }

    private func updateImage() async {
        
        let targetSize = loadFullResolution ? nil : compressedSize
        
        guard let url else {
            self.phase = .empty
            return
        }
        
        let request = URLRequest(url: url)

        if let cached = URLCache.shared.cachedResponse(for: request) {
            let image = cached.data.compressedImage(to: targetSize)
            if let image = image {
                self.phase = .success(Image(uiImage: image))
                return
            } else {
                URLCache.shared.removeCachedResponse(for: request)
            }
        }
        
        var data: Data!
        var response: URLResponse!
        
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            self.phase = .failure(LoadImageError.timeout)
            return
        }
        
        guard let response = response as? HTTPURLResponse, (200...300 ~= response.statusCode) else {
            self.phase = .failure(LoadImageError.badRequest)
            return
        }

        URLCache.shared.storeCachedResponse(.init(response: response, data: data), for: request)

        guard let image = data.compressedImage(to: targetSize) else {
            self.phase = .failure(LoadImageError.loadImageFailed)
            return
        }

        self.phase = .success(Image(uiImage: image))
        return
    }

}


private extension CGSize {
    var pngBytes: Int {
        Int(width * height * 9)
    }
    
    var jpegBytes: Int {
        Int(width * height * 3)
    }
}

private extension Data {

    func compressedImage(to size: CGSize?) -> UIImage? {
        guard let size = size else {
            return UIImage(data: self)
        }
        
        if self.count < size.pngBytes {
            return UIImage(data: self)
        }
        
        let scale = 2.0
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache : false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Swift.max(size.width, size.height) * scale
        ]
        
        guard
            let src = CGImageSourceCreateWithData(self as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
