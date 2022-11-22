//
//  FeedSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/21.
//

import SwiftUI

let noFolderName = "(No Folder)"

struct FeedSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(SettingKeys.keepDuration) var keepDuration: KeepDuration = .three

    @State private var title = ""
    @State private var folderName: String?
    @State private var preferWeb = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true

    @State private var folderNames = [String]()
    @State private var folderSelection = noFolderName
    @State private var pinned = false

    private var feed: CDFeed?
    private var updateErrorCount = ""
    private var lastUpdateError = ""
    private var url = ""
    private var added = ""
    private var initialTitle = ""
    private var initialFolderSelection = noFolderName

    init(_ selectedFeed: Int) {
        if let theFeed = CDFeed.feed(id: Int32(selectedFeed)),
           let folders = CDFolder.all() {
            self.feed = theFeed
            var fNames = [noFolderName]
            let names = folders.compactMap( { $0.name } )
            fNames.append(contentsOf: names)
            self._folderNames = State(initialValue: fNames)
            if let folder = CDFolder.folder(id: theFeed.folderId),
               let folderName = folder.name {
                self._folderSelection = State(initialValue: folderName)
                initialFolderSelection = folderName
            }
            initialTitle = theFeed.title ?? "Untitled"
            self._title = State(initialValue: initialTitle)
            self._preferWeb = State(initialValue: theFeed.preferWeb)
            self._pinned = State(initialValue: theFeed.pinned)
            updateErrorCount = "\(theFeed.updateErrorCount)"
            lastUpdateError = theFeed.lastUpdateError ?? "No error"
            url = theFeed.url ?? ""
            let dateAdded = Date(timeIntervalSince1970: TimeInterval(theFeed.added))
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            added = dateFormatter.string(from: dateAdded)
        }
    }

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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .symbolVariant(.circle.fill)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                            .accentColor(.secondary)
                    }
                }
            }
            .onChange(of: folderSelection) { [folderSelection] newFolder in
                if newFolder != folderSelection {
                    onFolderSelection(newFolder == noFolderName ? "" : newFolder)
                }
            }
            .onChange(of: preferWeb) { newValue in
                if let feed = self.feed {
                    feed.preferWeb = preferWeb
                    do {
                        try NewsData.mainThreadContext.save()
                    } catch {
                        //
                    }
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

    private func onTitleCommit() {
        if let feed = self.feed {
            if !title.isEmpty, title != feed.title {
                Task {
                    do {
                        try await NewsManager.shared.renameFeed(feed: feed, to: title)
                        feed.title = title
                        try NewsData.mainThreadContext.save()
                    } catch(let error as PBHError) {
                        switch error {
                        case .networkError(let message):
                            title = initialTitle
                            footerMessage = message
                            footerSuccess = false
                        default:
                            break
                        }
                    }
                }
            }
        }
    }

    private func onFolderSelection(_ newFolderName: String) {
        if let feed = self.feed {
            Task {
                var newFolderId: Int32 = 0
                if let newFolder = CDFolder.folder(name: newFolderName) {
                    newFolderId = newFolder.id
                }
                do {
                    try await NewsManager.shared.moveFeed(feed: feed, to: newFolderId)
                    feed.folderId = newFolderId
                    try NewsData.mainThreadContext.save()
                } catch(let error as PBHError) {
                    switch error {
                    case .networkError(let message):
                        folderSelection = initialFolderSelection
                        footerMessage = message
                        footerSuccess = false
                    default:
                        break
                    }
                }
            }
        }
    }

}

struct FeedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingsView(-2)
    }
}
