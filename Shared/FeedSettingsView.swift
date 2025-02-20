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
    @Environment(FeedModel.self) private var feedModel
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

    @Query private var folders: [Folder]
    @Query private var feeds: [Feed]

    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Title", text: $title) { isEditing in
                        if !isEditing {
                            onTitleCommit()
                        }
                    } onCommit: {
                        onTitleCommit()
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("") {
                        dismiss()
                    }
                    .buttonStyle(XButton())
                }
            }
            .task {
                switch feedModel.currentNode?.type {
                case .feed(id: let id):
                    if let feed = feeds.first(where: { $0.id == id }) {
                        var fNames = [noFolderName]
                        let names = folders.compactMap( { $0.name } ).sorted()
                        fNames.append(contentsOf: names)
                        folderNames = fNames
                        if let folder = feed.folder,
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
                    onFolderSelection(newValue == noFolderName ? "" : newValue)
                }
            }
            .onChange(of: preferWeb) { _, newValue in
// TODO               if let feed = feedModel.currentNode?.feed {
//                    feed.preferWeb = newValue
//                    Task {
//                        do {
//                            try await self.feedModel.backgroundModelActor.save()
//                        } catch {
//                            //
//                        }
//                    }
//                }
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

    @MainActor
    private func onTitleCommit() {
// TODO       if let feed = feedModel.currentNode?.feed {
//            if !title.isEmpty, title != feed.title {
//                Task {
//                    do {
//                        try await feedModel.renameFeed(feed: feed, to: title)
//                        self.feedModel.currentNode?.title = title
//                        feed.title = title
//                        try await self.feedModel.backgroundModelActor.save()
//                    } catch let error as NetworkError {
//                        title = initialTitle
//                        footerMessage = error.localizedDescription
//                        footerSuccess = false
//                    } catch let error as DatabaseError {
//                        title = initialTitle
//                        footerMessage = error.localizedDescription
//                        footerSuccess = false
//                    } catch let error {
//                        title = initialTitle
//                        footerMessage = error.localizedDescription
//                        footerSuccess = false
//                    }
//                }
//            }
//        }
    }

    @MainActor
    private func onFolderSelection(_ newFolderName: String) {
// TODO       if let feed = feedModel.currentNode?.feed {
//            Task {
//                var newFolderId: Int64 = 0
//                if let newFolder = folders.first(where: { $0.name == newFolderName }) {
//                    newFolderId = newFolder.id
//                }
//                do {
//                    try await feedModel.moveFeed(feed: feed, to: newFolderId)
//                    feed.folderId = newFolderId
//                    try await feedModel.backgroundModelActor.save()
//                } catch let error as NetworkError {
//                    folderSelection = initialFolderSelection
//                    footerMessage = error.localizedDescription
//                    footerSuccess = false
//                } catch let error as DatabaseError {
//                    folderSelection = initialFolderSelection
//                    footerMessage = error.localizedDescription
//                    footerSuccess = false
//                } catch let error {
//                    folderSelection = initialFolderSelection
//                    footerMessage = error.localizedDescription
//                    footerSuccess = false
//                }
//            }
//        }
    }

}

struct FeedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingsView()
    }
}
