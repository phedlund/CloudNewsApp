//
//  PagerWrapper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/24/22.
//

import SwiftUI

struct PagerWrapper: View {
#if os(iOS)
    @EnvironmentObject private var partialSheetManager: PartialSheetManager
#endif
//    @StateObject var page: Page = .first()
    @ObservedObject private var node: Node

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false
    @State private var currentModel = ArticleModel(item: nil)

    private var selectedIndex = 0

    init(node: Node, selectedIndex: Int) {
        self.node = node
        self.selectedIndex = selectedIndex
//        self._page = StateObject(wrappedValue: .withIndex(selectedIndex))
    }

    var body: some View {
#if !os(macOS)
#else
        ArticleView(model: node.items[selectedIndex])
            .navigationTitle(title)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onAppear {
                currentModel = node.items[selectedIndex]
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
            .toolbar(content: articleToolBarContent)
#endif
    }

    @ToolbarContentBuilder
    func articleToolBarContent() -> some ToolbarContent {
#if !os(macOS)
#else
            ToolbarItemGroup {
                Button {
                    currentModel.webView.goBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!canGoBack)
                Button {
                    currentModel.webView.goForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!canGoForward)
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
                Spacer()
                NSSharingService.submenu(text: currentModel.item?.url ?? "")
                .disabled(isLoading)
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    if let item = currentModel.item {
                        ArticleSettingsView(item: item)
                    }
                }
                .disabled(isLoading)
            }
#endif
    }

    private func markItemRead() {
        if let item = currentModel.item, item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

}

