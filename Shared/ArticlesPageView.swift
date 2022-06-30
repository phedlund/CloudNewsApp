//
//  ArticlesPageView.swift
//  ArticlesPageView
//
//  Created by Peter Hedlund on 9/5/21.
//

import SwiftUI
#if os(iOS)
struct ArticlesPageView: View {
    @EnvironmentObject private var settings: Preferences
    @ObservedObject private var node: Node
    @ObservedObject private var model: ArticleModel
    @State var selectedIndex: Int
    @State private var isShowingPopover = false
    @State private var currentModel = ArticleModel(item: nil)
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var title = ""

    init(model: ArticleModel, node: Node) {
        self.model = model
        self.node = node
        self.selectedIndex = node.items.firstIndex(of: model) ?? 0
    }

    var body: some View {
        print(Self._printChanges())
        return TabView(selection: $selectedIndex) {
            ForEach(Array(zip(node.items.indices, node.items)), id: \.1) { index, item in
                ArticleView(model: item)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(title)
        .background {
            Color.pbh.whiteBackground.ignoresSafeArea(edges: .vertical)
        }
        .onAppear {
            currentModel = node.items[selectedIndex]
            markItemRead()
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
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
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
                ShareLinkView(model: currentModel)
                    .disabled(isLoading)
                Button {
                    isShowingPopover = true
                } label: {
                    Image(systemName: "textformat.size")
                }
                .popover(isPresented: $isShowingPopover, attachmentAnchor: .point(.zero), arrowEdge: .top) {
                    if let item = currentModel.item {
                        ArticleSettingsView(item: item)
                            .presentationDetents([.height(300.0)])
                    }
                }
                .disabled(isLoading)
            }
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

//struct ArticlesPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        ArticlesPageView()
//    }
//}
#endif
