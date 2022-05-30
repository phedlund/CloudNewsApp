//
//  PagerWrapper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 4/24/22.
//

#if os(iOS)
import PartialSheet
#endif
import SwiftUI
import SwiftUIPager

struct PagerWrapper: View {
#if os(iOS)
    @EnvironmentObject private var partialSheetManager: PartialSheetManager
#endif
    @StateObject var page: Page = .first()
    @ObservedObject private var node: Node

    @State private var title = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var isShowingPopover = false
    @State private var isShowingSharePopover = false
    @State private var currentModel = ArticleModel(item: nil)

    private var selectedIndex = 0

#if !os(macOS)
    private var sharingProvider: SharingProvider? {
        var viewedUrl: URL?
        var subject = ""
        viewedUrl = currentModel.webView.url
        subject = currentModel.webView.title ?? ""
        if viewedUrl?.scheme?.hasPrefix("file") ?? false {
            if let urlString = currentModel.item?.url {
                viewedUrl = URL(string: urlString) ?? nil
                subject = currentModel.item?.title ?? "Untitled"
            }
        }

        if let url = viewedUrl {
            return SharingProvider(placeholderItem: url, subject: subject)
        }
        return nil
    }
#endif

    init(node: Node, selectedIndex: Int) {
        self.node = node
        self.selectedIndex = selectedIndex
        self._page = StateObject(wrappedValue: .withIndex(selectedIndex))
    }

    var body: some View {
#if !os(macOS)
        Pager(page: page,
              data: node.items,
              id: \.id,
              content: { index in
            ArticleView(model: index)
                .equatable()
                .tag(index.id)
        })
        .contentLoadingPolicy(.lazy(recyclingRatio: 2))
        .draggingAnimation(.standard(duration: 1.0))
        .onPageChanged { newValue in
            currentModel.webView.stopLoading()
            currentModel = node.items[newValue]
            markItemRead()
        }
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .addPartialSheet(style: .defaultStyle())
        .onAppear {
            currentModel = node.items[page.index]
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
#else
        ArticleView(model: node.items[selectedIndex])
            .navigationTitle(title)
            .background {
                Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
            }
            .onAppear {
                currentModel = node.items[page.index]
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
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Spacer(minLength: 10)
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
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingSharePopover = sharingProvider != nil
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .popover(isPresented: $isShowingSharePopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    ActivityView(activityItems: [sharingProvider!], applicationActivities: [SafariActivity()])
                }
                .disabled(isLoading)
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
                //                    Button {
                //                        isShowingSharePopover = sharingProvider != nil
                //                    } label: {
                //                        Image(systemName: "square.and.arrow.up")
                //                    }
                //                    .popover(isPresented: $isShowingSharePopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                //                        ActivityView(activityItems: [sharingProvider!], applicationActivities: [SafariActivity()])
                //                    }
                //                    .disabled(isLoading)
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

