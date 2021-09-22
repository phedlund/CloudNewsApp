//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI
import WebKit

class ArticleModel: ObservableObject, Identifiable {
    var item: CDItem
    var webView: WKWebView?
    @Published var isShowingData: Bool

    init(item: CDItem, isShowingData: Bool = false) {
        self.item = item
        self.isShowingData = isShowingData
    }
}

struct ArticlesPageView: View {
    @EnvironmentObject var treeModel: FeedTreeModel
    @ObservedObject var webViewManager = WebViewManager(type: .article)
    @State var selectedIndex: Int32 = -1
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false
    @State private var currentSize: CGSize = .zero
    @State private var sharingProvider: SharingProvider?
    @State private var currentModel: ArticleModel?

    var items: FetchedResults<CDItem>
    private var models = [ArticleModel]()

    init(items: FetchedResults<CDItem>, selectedIndex: Int32) {
        self.items = items

        _selectedIndex = State(initialValue: selectedIndex)
        for item in items {
            models.append(ArticleModel(item: item))
        }
        if let model = models.first(where: { $0.item.id == selectedIndex }) {
            currentModel = model
            webViewManager.resetWebView()
            model.webView = webViewManager.webView
            model.isShowingData = true
        }
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(models) { model in
               ArticleView(articleModel: model)
                    .tag(model.item.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: selectedIndex) { newValue in
            print("Selected Index \(newValue)")
            currentModel?.isShowingData = false
            if let model = models.first(where: { $0.item.id == newValue }) {
                currentModel = model
                webViewManager.resetWebView()
                model.webView = webViewManager.webView
                model.isShowingData = true
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarLeading) {
                Spacer(minLength: 10)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    webViewManager.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!webViewManager.canGoBack)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    webViewManager.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!webViewManager.canGoForward)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if webViewManager.isLoading {
                        webViewManager.webView.stopLoading()
                    } else {
                        webViewManager.webView.reload()
                    }
                } label: {
                    if webViewManager.isLoading  {
                        Image(systemName: "xmark")
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingSharePopover = canShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .popover(isPresented: $isShowingSharePopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    ActivityView(activityItems: [sharingProvider ?? []], applicationActivities: [SafariActivity()])
                }
                .disabled(webViewManager.isLoading)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    if let item = currentModel?.item {
                        ArticleSettingsView(item: item)
                    }
                }
                .disabled(webViewManager.isLoading)
            }
        })
    }

    private func canShare() -> Bool {
        var result = false
        var viewedUrl: URL?
        var subject = ""
        if let model = currentModel {
            viewedUrl = webViewManager.webView.url
            subject = webViewManager.webView.title ?? ""
            if viewedUrl?.absoluteString.hasSuffix("summary.html") ?? false {
                if let urlString = model.item.url {
                    viewedUrl = URL(string: urlString) ?? nil
                    subject = model.item.title ?? ""
                }
            }

            if let shareUrl = viewedUrl {
                sharingProvider = SharingProvider(placeholderItem: shareUrl, subject: subject)
                result = true
            }
        }
        return result
    }

}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}

public struct LazyView<Content: View>: View {
    private let build: () -> Content
    public init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    public var body: Content {
        build()
    }
}
