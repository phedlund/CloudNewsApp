//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI
import WebKit

struct ArticlesPageView: View {
    @State private var selectedIndex: Int = -1
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false
    @State private var currentModel: ArticleModel

    private var items: [ArticleModel]

    private var sharingProvider: SharingProvider? {
        var viewedUrl: URL?
        var subject = ""
        viewedUrl = currentModel.webView.url
        subject = currentModel.webView.title ?? ""
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
        .onChange(of: selectedIndex) { [selectedIndex] newValue in
            print("Old \(selectedIndex) New \(newValue)")
            currentModel.webView.stopLoading()
            currentModel = items[newValue]
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarLeading) {
                Spacer(minLength: 10)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    currentModel.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!currentModel.webView.canGoBack)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    currentModel.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!currentModel.webView.canGoForward)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if currentModel.webView.isLoading {
                        currentModel.webView.stopLoading()
                    } else {
                        currentModel.webView.reload()
                    }
                } label: {
                    if currentModel.webView.isLoading  {
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
                .disabled(currentModel.webView.isLoading)
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
                .disabled(currentModel.webView.isLoading)
            }
        })
    }

}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
