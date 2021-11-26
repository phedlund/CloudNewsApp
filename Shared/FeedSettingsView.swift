//
//  FeedSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/21.
//

import SwiftUI

struct FeedSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var folderName: String?
    @State private var preferWeb = false

    @State private var folderNames = [String]()
    @State private var folderSelection: String = "(No Folder)"
    @State private var currentFolderName = ""
    @State private var pinned = false

    private var feed: CDFeed?
    private var updateErrorCount = ""
    private var lastUpdateError = ""
    private var url = ""

    init(_ selectedFeed: Int) {
        if let theFeed = CDFeed.feed(id: Int32(selectedFeed)),
            let folders = CDFolder.all() {
            self.feed = theFeed
            var fNames = ["(No Folder)"]
            let names = folders.compactMap( { $0.name } )
            fNames.append(contentsOf: names)
            self._folderNames = State(initialValue: fNames)
            if let folder = CDFolder.folder(id: theFeed.folderId),
               let folderName = folder.name {
                self._folderSelection = State(initialValue: folderName)
                self._currentFolderName = State(initialValue: folderName)
            }
            self._title = State(initialValue: theFeed.title ?? "Untitled")
            self._preferWeb = State(initialValue: theFeed.preferWeb)
            self._pinned = State(initialValue: theFeed.pinned)
            updateErrorCount = "\(theFeed.updateErrorCount)"
            lastUpdateError = theFeed.lastUpdateError ?? "No error"
            url = theFeed.url ?? ""
        }
    }

    var body: some View {
        Form {
            Section("Settings") {
                HStack(spacing: 15) {
                    Text("Title")
                    TextField("Title", text: $title) { isEditing in
                        if !isEditing {
                            onTitleCommit()
                        }
                    } onCommit: {
                        onTitleCommit()
                    }
                }
                Picker("Folder", selection: $folderSelection) {
                    ForEach(folderNames, id: \.self) {
                        Text($0)
                    }
                    .navigationTitle("Folder")
                }
                Toggle("View web version", isOn: $preferWeb)
            }
            .navigationTitle("Feed Settings")
            Section {
                HStack(alignment: .lastTextBaseline, spacing: 15) {
                    Text("URL")
                    Text(verbatim: url)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Toggle("Pinned", isOn: $pinned)
                    .disabled(true)
                HStack(spacing: 15) {
                    Text("Update Error Count")
                    Spacer()
                    Text(verbatim: updateErrorCount)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
                HStack(spacing: 15) {
                    Text("Last Update Error")
                    Spacer()
                    Text(verbatim: lastUpdateError)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Information")
            } footer: {
                Text("Use the web interface to change or correct this information.\nThe last 30 days of articles will be kept locally.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                }
            }
        }
        .onChange(of: folderSelection) { _ in
            onFolderSelection()
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
    }

    private func onTitleCommit() {
        if let feed = self.feed {
            if !title.isEmpty, title != feed.title {
                Task {
                    do {
                        try await NewsManager.shared.renameFeed(feed: feed, to: title)
                        feed.title = title
                        try NewsData.mainThreadContext.save()
                    } catch {
                        //
                    }
                }
            }
        }
    }

    private func onFolderSelection() {
        if let feed = self.feed {
            if folderSelection != currentFolderName {
                if let newFolder = CDFolder.folder(name: folderSelection) {
                    Task {
                        do {
                            try await NewsManager.shared.moveFeed(feed: feed, to: newFolder.id)
                            feed.folderId = newFolder.id
                            try NewsData.mainThreadContext.save()
                        } catch {
                            //
                        }
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
