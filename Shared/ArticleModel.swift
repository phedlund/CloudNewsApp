//
//  ArticleModel.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/24/21.
//

import Combine
import Foundation
import Nuke
import WebKit

class ArticleModel: NSObject, ObservableObject, Identifiable {
    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var isLoading = false
    @Published public var title = ""

    @Published public var image: PlatformImage?
    @Published public var unread = true
    @Published public var starred = false
    @Published public var feedId: Int32 = 0
    @Published public var dateAuthorFeed = ""
    @Published public var displayBody = ""

    private var cancellables = Set<AnyCancellable>()
    private var observations = [NSKeyValueObservation]()
    private var internalWebView: WKWebView?

    var webView: WKWebView {
        get {
            if internalWebView == nil {
                let webConfig = WKWebViewConfiguration()
                webConfig.preferences.setValue(true, forKey: "fullScreenEnabled")
#if !os(macOS)
                webConfig.allowsInlineMediaPlayback = true
#endif
                webConfig.mediaTypesRequiringUserActionForPlayback = [.all]

                internalWebView = WKWebView(frame: .zero, configuration: webConfig)
                setupObservations()
            }
            return internalWebView!
        }
    }
    var item: CDItem?

    init(item: CDItem?) {
        self.item = item
        super.init()
        if let item = item {
            item
                .publisher(for: \.imageLink)
                .sink {
                    guard self.image == nil else {
                        return
                    }
                    if let imageLink = $0 {
                        guard imageLink != "data:null" else {
                            return
                        }
                        if imageLink.isEmpty {
                            ItemImageFetcher().itemURL(item)
                        } else if let url = URL(withCheck: imageLink) {
                            print("Creating image request")
                            let request = ImageRequest(urlRequest: URLRequest(url: url),
                                                       processors: [SizeProcessor(item: item),
                                                                    ImageProcessors.Resize(size: CGSize(width: 145.0, height: 160.0),
                                                                                           unit: .points,
                                                                                           contentMode: .aspectFill,
                                                                                           crop: true,
                                                                                           upscale: true)],
                                                       priority: .veryHigh,
                                                       options: [],
                                                       userInfo: nil)
                            ImagePipeline.shared.imagePublisher(with: request)
                                .sink(receiveCompletion: { _ in /* Ignore errors */ },
                                      receiveValue: { [weak self] in
                                    self?.image = $0.image
                                })
                                .store(in: &self.cancellables)
                        }
                    } else {
                        ItemImageFetcher().itemURL(item)
                    }
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.unread)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.unread = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.starred)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.starred = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.feedId)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.feedId = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.dateAuthorFeed)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.dateAuthorFeed = $0
                }
                .store(in: &cancellables)
            item
                .publisher(for: \.displayBody)
                .receive(on: DispatchQueue.main)
                .sink {
                    self.displayBody = $0 ?? ""
                }
                .store(in: &cancellables)
            title = item.title ?? "Untitled"
        }
    }

    private func setupObservations() {
        webView.publisher(for: \.canGoBack).sink { [weak self] newValue in
            self?.canGoBack = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.canGoForward).sink { [weak self] newValue in
            self?.canGoForward = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.isLoading).sink { [weak self] newValue in
            self?.isLoading = newValue
            }
        .store(in: &cancellables)
        webView.publisher(for: \.title).sink { [weak self] newValue in
            if let newTitle = newValue, !newTitle.isEmpty {
                self?.title = newTitle
            }
        }
        .store(in: &cancellables)
#if !os(macOS)
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification, object: nil).sink { [weak self] _ in
            self?.webView.reload()
        }
        .store(in: &cancellables)
#endif
        Task {
            do {
                if let rules = try await ContentBlocker.ruleList() {
                    DispatchQueue.main.async { [weak self] in
                        self?.webView.configuration.userContentController.add(rules)
                    }
                }
            } catch {
                //
            }
        }
    }

}
