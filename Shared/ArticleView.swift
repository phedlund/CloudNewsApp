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
    @State private var url = URL(fileURLWithPath: "")
    @State private var isShowingPopover = false
    @State private var currentSize: CGSize = .zero

    var item: CDItem

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text("Hello World")
                    .font(.system(size: CGFloat(fontSize), weight: .regular, design: .default))
                ArticleWebView(url: $url)
                    .onAppear {
                        currentSize = geometry.size
                        url = configureView(size: currentSize) ?? URL(fileURLWithPath: "")
                    }
                    .onChange(of: fontSize, perform: { _ in
                        url = URL(fileURLWithPath: "") // force a change of url
                        url = configureView(size: currentSize) ?? URL(fileURLWithPath: "")
                    })
                    .onChange(of: marginPortrait, perform: { _ in
                        url = URL(fileURLWithPath: "") // force a change of url
                        url = configureView(size: currentSize) ?? URL(fileURLWithPath: "")
                    })
                    .onChange(of: marginLandscape, perform: { _ in
                        url = URL(fileURLWithPath: "") // force a change of url
                        url = configureView(size: currentSize) ?? URL(fileURLWithPath: "")
                    })
                    .onChange(of: lineHeight, perform: { _ in
                        url = URL(fileURLWithPath: "") // force a change of url
                        url = configureView(size: currentSize) ?? URL(fileURLWithPath: "")
                    })
                    .toolbar(content: {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                //
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
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
                        }
                    })
                    .navigationTitle(item.title ?? "Untitled")
    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
#endif
            }
        }
    }

    private func configureView(size: CGSize) -> URL? {
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
                return saveItemSummary(html: html, item: item, feedTitle: "Feed Title", size: size)
            }
//        }
        return nil
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
        StatefulPreviewWrapper(URL(fileURLWithPath: "")) {
            ArticleWebView(url: $0)
        }

    }
}

