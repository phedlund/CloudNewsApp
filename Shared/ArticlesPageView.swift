//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import PartialSheet
import SwiftUI
import WebKit

struct ArticlesPageView: View {
    @EnvironmentObject private var partialSheetManager: PartialSheetManager

    @State private var selectedIndex: Int
    @State private var isShowingPopover = false
    @State private var isShowingPartialSheet = false
    @State private var isShowingSharePopover = false
    @State private var currentModel: ArticleModel
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var title = ""

    private var node: Node

    private var sharingProvider: SharingProvider? {
        var viewedUrl: URL?
        var subject = ""
        viewedUrl = currentModel.webView.url
        subject = currentModel.webView.title ?? ""
        if viewedUrl?.scheme?.hasPrefix("file") ?? false {
            if let urlString = currentModel.item.url {
                viewedUrl = URL(string: urlString) ?? nil
                subject = currentModel.item.title ?? "Untitled"
            }
        }
        
        if let url = viewedUrl {
            return SharingProvider(placeholderItem: url, subject: subject)
        }
        return nil
    }

    init(node: Node, selectedIndex: Int) {
        self.node = node
        _currentModel = State(initialValue: node.items[selectedIndex])
        _selectedIndex = State(initialValue: selectedIndex)
        markItemRead()
    }

    var body: some View {
        print(Self._printChanges())
        return TabView(selection: $selectedIndex) {
            ForEach(node.items.indices, id: \.self) { index in
                ArticleView(model: node.items[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .addPartialSheet(style: .defaultStyle())
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onChange(of: selectedIndex) { newValue in
            currentModel.webView.stopLoading()
            currentModel = node.items[newValue]
            markItemRead()
        }
        .onReceive(currentModel.$canGoBack) {
            canGoBack = $0
        }
        .onReceive(currentModel.$canGoForward) {
            canGoForward = $0
        }
        .onReceive(currentModel.$isLoading) {
            isLoading = $0
        }
        .onReceive(currentModel.$title) {
            if $0 != title {
                title = $0
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarLeading) {
                Spacer(minLength: 10)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Spacer(minLength: 10)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    currentModel.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!canGoBack)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    currentModel.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!canGoForward)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if isLoading {
                        currentModel.webView.stopLoading()
                    } else {
                        currentModel.webView.reload()
                    }
                } label: {
                    if isLoading {
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
                .disabled(isLoading)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        self.partialSheetManager.showPartialSheet({
                            print("Partial sheet dismissed")
                        }) {
                            if let item = currentModel.item {
                                ArticleSettingsView(item: item)
                            }
                        }
                    } else {
                        isShowingPopover = true
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    if let item = currentModel.item {
                        ArticleSettingsView(item: item)
                    }
                }
                .disabled(isLoading)
            }
        })
    }

    private func markItemRead() {
        if currentModel.item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [currentModel.item], unread: false)
            }
        }
    }
}

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
