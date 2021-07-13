//
//  ArticleView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/19/21.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @AppStorage(StorageKeys.fontSize) var fontSize: Int = UIDevice().userInterfaceIdiom == .pad ? 16 : 13
    @AppStorage(StorageKeys.marginPortrait) var marginPortrait: Int = 70
    @AppStorage(StorageKeys.marginLandscape) var marginLandscape: Int = 70
    @AppStorage(StorageKeys.lineHeight) var lineHeight: Double = 1.4

    @StateObject var webViewManager = WebViewManager()

    @State private var isShowingPopover = false
    @State private var currentSize: CGSize = .zero

    var item: CDItem

    private var url = URL(fileURLWithPath: "")
    private var webView: ArticleWebView?

    init(item: CDItem) {
        self.item = item
        url = documentsFolderURL?
            .appendingPathComponent("summary")
            .appendingPathExtension("html") ?? URL(fileURLWithPath: "")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                ArticleWebView(webView: webViewManager.webView)
                    .onAppear {
                        currentSize = geometry.size
                        configureView(size: currentSize)
                        webViewManager.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                        delayMarkingRead()
                    }
                    .onChange(of: fontSize, perform: { _ in
                        configureView(size: currentSize)
                        webViewManager.webView.reload()
                    })
                    .onChange(of: marginPortrait, perform: { _ in
                        configureView(size: currentSize)
                        webViewManager.webView.reload()
                    })
                    .onChange(of: marginLandscape, perform: { _ in
                        configureView(size: currentSize)
                        webViewManager.webView.reload()
                    })
                    .onChange(of: lineHeight, perform: { _ in
                        configureView(size: currentSize)
                        webViewManager.webView.reload()
                    })
                    .toolbar(content: {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                webViewManager.webView.goBack()
                            } label: {
                                Image(systemName: "chevron.backward")
                            }
                            .disabled(!webViewManager.webView.canGoBack)
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                webViewManager.webView.goForward()
                            } label: {
                                Image(systemName: "chevron.forward")
                            }
                            .disabled(!webViewManager.webView.canGoForward)
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                if webViewManager.webView.isLoading {
                                    webViewManager.webView.stopLoading()
                                } else {
                                    webViewManager.webView.reload()
                                }
                            } label: {
                                if webViewManager.webView.isLoading {
                                    Image(systemName: "xmark")
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                //
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .disabled(webViewManager.webView.isLoading)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                isShowingPopover = true
                            } label: {
                                Image(systemName: "textformat.size")
                            }
                            .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                                ArticleSettingsView()
                            }
                            .disabled(webViewManager.webView.isLoading)
                        }
                    })
                    .navigationTitle(item.title ?? "Untitled")
    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
            }
        }
    }

    private func delayMarkingRead() {
        // The delay prevents the view from jumping back to the items list
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if item.unread {
                async {
                    try? await NewsManager.shared.markRead(items: [item], unread: false)
                }
            }
        }
    }

    private func configureView(size: CGSize) {
//        if item.item.feedPreferWeb == true {
//            if item.item.feedUseReader == true {
//                if let readable = item.item.readable, readable.count > 0 {
//                    writeAndLoadHtml(html: readable, feedTitle: item.feedTitle)
//                } else {
//                    if let urlString = item.url {
//                        OCAPIClient.shared().requestSerializer = OCAPIClient.httpRequestSerializer()
//                        OCAPIClient.shared().get(urlString, parameters: nil, headers: nil, progress: nil, success: { [weak self] (task, responseObject) in
//                            var html: String
//                            if let response = responseObject as? Data, let source = String.init(data: response, encoding: .utf8), let url = task.response?.url {
//                                if let article = ArticleHelper.readble(html: source, url: url) {
//                                    html = article
//                                } else {
//                                    html = "<p style='color: #CC6600;'><i>(An article could not be extracted. Showing summary instead.)</i></p>"
//                                    if let body = item.item.body {
//                                        html = html + body
//                                    }
//                                }
//                            } else {
//                                html = "<p style='color: #CC6600;'><i>(An article could not be extracted. Showing summary instead.)</i></p>"
//                                if let body = item.item.body {
//                                    html = html + body
//                                }
//                            }
//                            self?.writeAndLoadHtml(html: html, feedTitle: item.feedTitle)
//                        }) { [weak self]  (_, _) in
//                            var html = "<p style='color: #CC6600;'><i>(There was an error downloading the article. Showing summary instead.)</i></p>"
//                            if let body = item.item.body {
//                                html = html + body
//                            }
//                            self?.writeAndLoadHtml(html: html, feedTitle: item.feedTitle)
//                        }
//                    }
//                }
//            } else {
//                if let url = URL(string: item.url ?? "") {
//                    webView?.load(URLRequest(url: url))
//                }
//            }
//        } else {
            if var html = item.body,
                let urlString = item.url,
                let url = URL(string: urlString) {
                let baseString = "\(url.scheme ?? "")://\(url.host ?? "")"
                if baseString.range(of: "youtu", options: .caseInsensitive) != nil {
                    if html.range(of: "iframe", options: .caseInsensitive) != nil {
                        html = createYoutubeItem(html: html, urlString: urlString)
                    } else if let urlString = item.url, urlString.contains("watch?v="), let equalIndex = urlString.firstIndex(of: "=") {
                        let videoIdStartIndex = urlString.index(after: equalIndex)
                        let videoId = String(urlString[videoIdStartIndex...])
                        let screenSize = UIScreen.main.nativeBounds.size
                        let margin = marginPortrait
                        let currentWidth = Double(screenSize.width / UIScreen.main.scale) * (Double(margin) / 100.0)
                        let newheight = currentWidth * 0.5625
                        let embed = "<embed id=\"yt\" src=\"http://www.youtube.com/embed/\(videoId)?playsinline=1\" type=\"text/html\" frameborder=\"0\" width=\"\(Int(currentWidth))px\" height=\"\(Int(newheight))px\"></embed>"
                        html = embed
                    }
                }
                html = fixRelativeUrl(html: html, baseUrlString: baseString)
                saveItemSummary(html: html, item: item, feedTitle: "Feed Title", size: size)
            }
//        }
    }

}

struct PopoverView: View {
    var body: some View {
        Text("Popover Content")
            .padding()
    }
}

struct StatefulPreviewWrapper<Value, Content: View>: View {
   @State var value: Value
   var content: (Binding<Value>) -> Content

   public var body: some View {
       content($value)
   }

   public init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
       self._value = State(wrappedValue: value)
       self.content = content
   }
}

struct ArticleView_Previews: PreviewProvider {
    static var previews: some View {
        ArticleWebView(webView: WebViewManager().webView)
    }
}

