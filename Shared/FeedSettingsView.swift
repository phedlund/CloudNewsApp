//
//  FeedSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/21.
//

import SwiftData
import SwiftUI

let noFolderName = "(No Folder)"

struct FeedSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NewsModel.self) private var newsModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingKeys.keepDuration) var keepDuration: KeepDuration = .three

    @State private var title = ""
    @State private var folderName: String?
    @State private var preferWeb = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    @State private var folderNames = [String]()
    @State private var folderSelection = noFolderName
    @State private var pinned = false
    @State private var updateErrorCount = ""
    @State private var lastUpdateError = ""
    @State private var url = ""
    @State private var added = ""
    @State private var initialTitle = ""
    @State private var initialFolderSelection = noFolderName

    @Query private var nodes: [Node]
    @Query private var folders: [Folder]
    @Query private var feeds: [Feed]
    @Query private var favIcons: [FavIcon]

    var body: some View {
        VStack {
            Form {
                Section {
                    favIconView
                        .alignmentGuide(.listRowSeparatorLeading) { d in
                                    d[.leading]
                                }
                    TextField("Title", text: $title) { isEditing in
                        if !isEditing {
                            Task {
                                await onTitleCommit()
                            }
                        }
                    } onCommit: {
                        Task {
                            await onTitleCommit()
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    Picker(selection: $folderSelection) {
                        ForEach(folderNames, id: \.self) {
                            Text($0)
                        }
                        .navigationTitle("Folder")
                    } label: {
                      Text("Folder")
                    }
                    Toggle(isOn: $preferWeb) {
                        Text("View web version")
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    FooterLabel(message: footerMessage, success: footerSuccess)
                }
                Section {
                    LabeledContent {
                        Text(verbatim: url)
                            .textSelection(.enabled)
                    } label: {
                        Text("URL")
                    }
                    LabeledContent {
                        Text(verbatim: added)
                    } label: {
                        Text("Date Added")
                    }
                    Toggle(isOn: $pinned) {
                        Text("Pinned")
                    }
                    .disabled(true)
                    LabeledContent {
                        Text(verbatim: updateErrorCount)
                    } label: {
                        Text("Update Error Count")
                    }
                    LabeledContent {
                        Text(verbatim: lastUpdateError)
                    } label: {
                        Text("Last Update Error")
                    }
                } header: {
                    Text("Information")
                } footer: {
                    Text("Use the web interface to change or correct this information.\nThe last \(keepDuration.rawValue) months of articles will be kept locally.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Feed Settings")
#if !os(macOS)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
#endif
            .task {
                switch newsModel.currentNodeType {
                case .feed(id: let id):
                    if let feed = feeds.first(where: { $0.id == id }) {
                        var fNames = [noFolderName]
                        let names = folders.compactMap( { $0.name } ).sorted()
                        fNames.append(contentsOf: names)
                        folderNames = fNames
                        if let folder = folders.first(where: { $0.id == feed.folderId }),
                           let folderName = folder.name {
                            folderSelection = folderName
                            initialFolderSelection = folderName
                        }
                        initialTitle = feed.title ?? "Untitled"
                        title = initialTitle
                        preferWeb = feed.preferWeb
                        pinned = feed.pinned
                        updateErrorCount = "\(feed.updateErrorCount)"
                        lastUpdateError = feed.lastUpdateError ?? "No error"
                        url = feed.url ?? ""
                        let dateAdded = feed.added
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .long
                        added = dateFormatter.string(from: dateAdded)
                    }
                default:
                    break
                }
            }
            .onChange(of: folderSelection) { oldValue, newValue in
                if newValue != oldValue {
                    Task {
                        await onFolderSelection(newValue == noFolderName ? "" : newValue)
                    }
                }
            }
            .onChange(of: preferWeb) { _, newValue in
                if let feed = feedForNodeType(newsModel.currentNodeType) {
                    feed.preferWeb = newValue
                }
            }
#if os(macOS)
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .buttonStyle(.bordered)
            }
            .padding()
#endif
        }
    }

    private func onTitleCommit() async {
        if let feed = feedForNodeType(newsModel.currentNodeType),
            let node = nodes.first(where: { $0.type == newsModel.currentNodeType } ) {
            if !title.isEmpty, title != feed.title {
                do {
                    try await newsModel.renameFeed(feedId: feed.id, to: title)
                    node.title = title
                    feed.title = title
                    try modelContext.save()
                } catch let error as NetworkError {
                    title = initialTitle
                    footerMessage = error.localizedDescription
                    footerSuccess = false
                } catch let error as DatabaseError {
                    title = initialTitle
                    footerMessage = error.localizedDescription
                    footerSuccess = false
                } catch let error {
                    title = initialTitle
                    footerMessage = error.localizedDescription
                    footerSuccess = false
                }
            }
        }
    }

    private func onFolderSelection(_ newFolderName: String) async {
        if let feed = feedForNodeType(newsModel.currentNodeType), let node = nodes.first(where: { $0.type == newsModel.currentNodeType } ) {
            var newFolderId: Int64 = 0
            if let newFolder = folders.first(where: { $0.name == newFolderName }) {
                newFolderId = newFolder.id
            }
            do {
                try await newsModel.moveFeed(feedId: feed.id, to: newFolderId)
                if newFolderId == 0 {
                    node.parent = nil
                } else {
                    if let newParentNode = nodes.first(where: { $0.type == NodeType.folder(id: newFolderId) }) {
                        newParentNode.children?.append(node)
                    }
                }
                feed.folderId = newFolderId
                try modelContext.save()
            } catch let error as NetworkError {
                folderSelection = initialFolderSelection
                footerMessage = error.localizedDescription
                footerSuccess = false
            } catch let error as DatabaseError {
                folderSelection = initialFolderSelection
                footerMessage = error.localizedDescription
                footerSuccess = false
            } catch let error {
                folderSelection = initialFolderSelection
                footerMessage = error.localizedDescription
                footerSuccess = false
            }
        }
    }

    private func feedForNodeType(_ nodeType: NodeType) -> Feed? {
        switch nodeType {
        case .empty, .all, .unread, .starred, .folder:
            return nil
        case .feed(let id):
            return feeds.first(where: { $0.id == id })
        }
    }

    private func refreshFavIcon() async {
        if let feed = feedForNodeType(newsModel.currentNodeType) {
            do {
                try await newsModel.addFavIcon(feedId: feed.id, faviconLink: feed.faviconLink, link: feed.link)
            } catch {
                //
            }
        }
    }

    var favIconView: some View {
        HStack {
            switch newsModel.currentNodeType {
            case .feed(id: let id):
                if let favicon = favIcons.first(where: { $0.id == id }),
                   let data = favicon.icon,
                   let uiImage = SystemImage(data: data) {
#if os(macOS)
                    Image(nsImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
#else
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
#endif
                } else {
                    Image(.rss)
                        .font(.system(size: 36, weight: .light))
                }
            default:
                EmptyView()
            }
            Spacer()
            Button {
                Task {
                    await refreshFavIcon()
                }
            } label: {
                Text("Refresh")
            }
            .buttonStyle(.bordered)
        }
    }

}

struct FeedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingsView()
    }
}
