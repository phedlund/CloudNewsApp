//
//  FolderRenameView.swift
//  FolderRenameView
//
//  Created by Peter Hedlund on 7/16/21.
//

import SwiftUI

struct FolderRenameView: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage(StorageKeys.selectedFeed) private var selectedFeed: Int = 0

    @Binding var showModal: Bool

    @State private var folder: CDFolder?
    @State private var folderName = ""

    var body: some View {
        VStack {
            Text("Rename Folder")
                .font(.headline)
            Text("Enter the new name of the folder")
                .font(.subheadline)
            TextField("Name", text: $folderName)
                .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            Spacer()
            Divider()
            Button {
                onSave()
                dismiss()
            } label: {
                Text("Rename")
            }
        }
        .padding()
        .textFieldStyle(.roundedBorder)
        .buttonStyle(.bordered)
        .frame(width: 250, height: 200)
        .onAppear {
            folder = CDFolder.folder(id: Int32(selectedFeed))
            folderName = folder?.name ?? "Untitled"
        }
    }

    private func onSave() {
        if let folder = folder {
            if folderName != folder.name {
                Task {
                    do {
                        folder.name = folderName
                        try NewsData.mainThreadContext.save()
                        try await NewsManager.shared.renameFolder(folder: folder, to: folderName)
                    } catch {
                        //
                    }
                }
            }
        }
    }
}

struct FolderRenameView_Previews: PreviewProvider {
    static var previews: some View {
        FolderRenameView(showModal: .constant(true))
    }
}
