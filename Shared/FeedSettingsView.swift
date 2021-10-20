//
//  FeedSettingsView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/13/21.
//

import SwiftUI

struct FeedSettingsView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0

    @State private var feed: CDFeed?
    @State private var title = ""
    @State private var folderName: String?
    @State private var preferWeb = false
    @State private var pinned = false
    @State private var folderNames = [String]()
    @State private var folderSelection: String = "(No Folder)"
    @State private var currentFolderName = ""
    @State private var updateErrorCount = ""
    @State private var lastUpdateError = ""

    var body: some View {
        Form {
            Section("Settings") {
                HStack(spacing: 15) {
                    Text("Title")
                    TextField("Title", text: $title)
                }
                Picker("Folder", selection: $folderSelection) {
                    ForEach(folderNames, id: \.self) {
                        Text($0)
                    }
                }
                Toggle("View web version", isOn: $preferWeb)
            }
            Section {
                HStack(alignment: .lastTextBaseline, spacing: 15) {
                    Text("URL")
                    Text(verbatim: feed?.url ?? "")
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
        .onAppear {
            if folderNames.isEmpty, let folders = CDFolder.all() {
                self.feed = CDFeed.feed(id: Int32(selectedFeed))
                folderNames.append("(No Folder)")
                let names = folders.compactMap( { $0.name } )
                folderNames.append(contentsOf: names)
                if let folder = CDFolder.folder(id: feed?.folderId ?? 0),
                   let folderName = folder.name {
                    folderSelection = folderName
                    currentFolderName = folderName
                }
                title = feed?.title ?? "Untitled"
                preferWeb = feed?.preferWeb ?? false
                pinned = feed?.pinned ?? false
                updateErrorCount = "\(feed?.updateErrorCount ?? 0)"
                lastUpdateError = feed?.lastUpdateError ?? "No error"
            }
        }
        .navigationTitle("Feed Settings")
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Save")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                }
            }
        })
    }

    private func onSave() {
        if let feed = self.feed {
            if folderSelection != currentFolderName {
                if let newFolder = CDFolder.folder(name: folderSelection) {
                    feed.folderId = newFolder.id
                    Task {
                        do {
                            try await NewsManager.shared.moveFeed(feed: feed, to: newFolder.id)
                        } catch {
                            //
                        }
                    }
                }
            }
            if !title.isEmpty, title != feed.title {
                feed.title = title
                Task {
                    do {
                        try await NewsManager.shared.renameFeed(feed: feed, to: title)
                    } catch {
                        //
                    }
                }
            }
            feed.preferWeb = preferWeb
            feed.articleCount = stepperValue
            do {
                try NewsData.mainThreadContext.save()
            } catch {
                //
            }
        }
    }

}

struct FeedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingsView()
    }
}
