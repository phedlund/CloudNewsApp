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
    @Environment(\.managedObjectContext) private var moc
    @AppStorage(SettingKeys.keepDuration) var keepDuration: KeepDuration = .three

    @State private var title = ""
    @State private var folderName: String?
    @State private var preferWeb = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true

    @State private var folderNames = [String]()
    @State private var folderSelection = noFolderName
    @State private var pinned = false

    private var feed: Feed?
    private var updateErrorCount = ""
    private var lastUpdateError = ""
    private var url = ""
    private var added = ""
    private var initialTitle = ""
    private var initialFolderSelection = noFolderName

    init(_ selectedFeed: Int) {
        if let theFeed = Feed.feed(id: Int64(selectedFeed)),
           let folders = Folder.all() {
            self.feed = theFeed
            var fNames = [noFolderName]
            let names = folders.compactMap( { $0.name } )
            fNames.append(contentsOf: names)
            self._folderNames = State(initialValue: fNames)
            if let folder = Folder.folder(id: theFeed.folderId),
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
                    Button("") {
                        dismiss()
                    }
                    .buttonStyle(XButton())
                }
            }
            .onChange(of: folderSelection) { oldValue, newValue in
                if newValue != oldValue {
                    onFolderSelection(newValue == noFolderName ? "" : newValue)
                }
            }
            .onChange(of: preferWeb) { _, newValue in
                if let feed = self.feed {
                    feed.preferWeb = newValue
                    do {
                        try moc.save()
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
                        try moc.save()
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
    }

    private func onFolderSelection(_ newFolderName: String) {
        if let feed = self.feed {
            Task {
                var newFolderId: Int64 = 0
                if let newFolder = Folder.folder(name: newFolderName) {
                    newFolderId = newFolder.id
                }
                do {
                    try await NewsManager.shared.moveFeed(feed: feed, to: newFolderId)
                    feed.folderId = newFolderId
                    try await NewsData.shared.container?.mainContext.save()
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
    }

}

struct FeedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        FeedSettingsView(-2)
    }
}
