//
//  PrefetchAsyncImage.swift
//  CloudNews
//

import SwiftUI
import UIKit

struct PrefetchAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url else { return }

        if let cached = ImagePrefetchManager.shared.getImage(for: url) {
            image = cached
            return
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let decoded = await Task.detached(priority: .userInitiated) {
                ImageUtils.decompressImage(data: data)
            }.value

            if let decoded = decoded {
                image = decoded
            }
        } catch {
            //
        }
    }
}
