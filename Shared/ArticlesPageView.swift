//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI
import WebKit

struct ArticlesPageView: View {
    @ObservedObject var webViewManager = WebViewManager(type: .article)
    @State var selectedIndex: Int = -1
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false
    @State private var currentSize: CGSize = .zero
    @State private var currentModel: ArticleModel

    var items: [ArticleModel]

    private var sharingProvider: SharingProvider? {
        var viewedUrl: URL?
        var subject = ""
        viewedUrl = webViewManager.webView.url
        subject = webViewManager.webView.title ?? ""
        if viewedUrl?.absoluteString.hasSuffix("summary.html") ?? false {
            if let urlString = currentModel.item.url {
                viewedUrl = URL(string: urlString) ?? nil
                subject = currentModel.item.displayTitle
            }
        }
        
        if let url = viewedUrl {
            return SharingProvider(placeholderItem: url, subject: subject)
        }
        return nil
    }

    init(items: [ArticleModel], selectedIndex: Int) {
        self.items = items
        currentModel = items[selectedIndex]
        _selectedIndex = State(initialValue: selectedIndex)
        webViewManager.resetWebView()
        currentModel.webView = webViewManager.webView
        currentModel.isShowingData = true
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(items.indices, id: \.self) { index in
                ArticleView(articleModel: items[index])
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: selectedIndex) { newValue in
            currentModel.isShowingData = false
            webViewManager.webView.stopLoading()
            currentModel = items[newValue]
            if let existingWebView = currentModel.webView {
                webViewManager.webView = existingWebView
            } else {
                webViewManager.resetWebView()
                currentModel.webView = webViewManager.webView
            }
            currentModel.isShowingData = true
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
                    isShowingSharePopover = sharingProvider != nil
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .popover(isPresented: $isShowingSharePopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    ActivityView(activityItems: [sharingProvider!], applicationActivities: [SafariActivity()])
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
                    if let item = currentModel.item {
                        ArticleSettingsView(item: item)
                    }
                }
                .disabled(webViewManager.isLoading)
            }
        })
    }

}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
