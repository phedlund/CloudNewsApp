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
        self._page = StateObject(wrappedValue: .withIndex(selectedIndex))
    }

    var body: some View {
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
#if !os(macOS)
        .addPartialSheet(style: .defaultStyle())
#endif
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
        .toolbar {
#if !os(macOS)
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
#else
            ToolbarItem {
                Spacer(minLength: 10)
            }
#endif
        }
    }

    private func markItemRead() {
        if let item = currentModel.item, item.unread {
            Task {
                try? await NewsManager.shared.markRead(items: [item], unread: false)
            }
        }
    }

}

