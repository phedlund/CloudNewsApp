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
    @ViewBuilder var content: (AsyncImagePhase) -> Content
    
    @State private var uiImage: UIImage? = nil
    @State private var phase: AsyncImagePhase = .empty
    

    var body: some View {
        content(phase)
            .onChange(of: url, initial: true) {
                Task {
                    await self.updateImage()
                }
            }
    }

    private func updateImage() async {
        guard let url else {
            self.phase = .empty
            return
        }
        
        let request = URLRequest(url: url)

        if let cached = URLCache.shared.cachedResponse(for: request) {
            let image = UIImage(data: cached.data)
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

        guard let image = UIImage(data: data) else {
            self.phase = .failure(LoadImageError.loadImageFailed)
            return
        }

        self.phase = .success(Image(uiImage: image))
        return
    }

}
