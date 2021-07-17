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
    @State private var stepperValue: Int32 = 250
    @State private var folderNames = [String]()
    @State private var folderSelection: String = "(No Folder)"
    @State private var currentFolderName = ""

    var body: some View {
        Form {
            VStack(alignment: .leading) {
                Text("URL")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(verbatim: feed?.url ?? "")
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading) {
                Text("Title")
                    .font(.headline)
                    .foregroundColor(.secondary)
                TextField("Title", text: $title)
            }
            Picker("Folder", selection: $folderSelection) {
                ForEach(folderNames, id: \.self) {
                    Text($0)
                }
            }
            Toggle("View web version", isOn: $preferWeb)
            HStack {
                Stepper(value: $stepperValue, in: 10...500, step: 10) {
                    HStack {
                        Text("Articles to keep")
                        Spacer()
                        Text("\(stepperValue)")
                    }
                }
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
                stepperValue = feed?.articleCount ?? 250
                title = feed?.title ?? "Untitled"
                preferWeb = feed?.preferWeb ?? false
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
