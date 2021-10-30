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
    @State private var currentSize: CGSize = .zero
    @State private var currentModel: ArticleModel
    @State private var processedItems: [ArticleModel]

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
        var initialItems = [ArticleModel]()
        var count = 0
        while ((initialItems.count < 5) && (count < items.count)) {
            print("Processed Count \(initialItems.count)")
            switch selectedIndex {
            case 0:
                let isIndexValid = items.indices.contains(selectedIndex + count)
                if isIndexValid {
                    initialItems.append(items[selectedIndex + count])
                }
                count += 1
            case items.count - 1:
                let isIndexValid = items.indices.contains(items.count - 1 - count)
                if isIndexValid {
                    initialItems.append(items[items.count - 1 - count])
                }
                count += 1
            default:
                switch items.count {
                case 3:
                    initialItems = [items[0], items[1], items[2]]
                case 4:
                    initialItems = [items[0], items[1], items[2], items[3]]
                case 5:
                    initialItems = [items[0], items[1], items[2], items[3], items[4]]
                default:
                    var internalCount = selectedIndex + 4
                    while initialItems.count < 5 {
                        let isIndexValid = items.indices.contains(internalCount)
                        if isIndexValid {
                            initialItems.append(items[internalCount])
                        }
                        internalCount -= 1
                    }
                }
                count = 5
            }
        }
        _processedItems = State(initialValue: initialItems)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(processedItems.indices, id: \.self) { index in
                ArticleView(articleModel: processedItems[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: selectedIndex) { newValue in
            currentModel.webView.stopLoading()
            currentModel = processedItems[newValue]
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
