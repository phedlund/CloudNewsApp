//
//  FolderRenameView.swift
//  FolderRenameView
//
//  Created by Peter Hedlund on 7/16/21.
//

import SwiftUI

struct FolderRenameView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var selectedFeed: Int

    @State private var folder: CDFolder?
    @State private var folderName = ""
    @State private var footerLabel = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                Button {
                    onSave()
                    dismiss()
                } label: {
                    Text("Rename")
                }
                .buttonStyle(.bordered)
                .disabled(folderName.isEmpty)
            } header: {
                Text("Rename Folder")
            } footer: {
                Text(footerLabel)
            }
        }
        .navigationTitle("Folder Name")
        .onAppear {
            DispatchQueue.main.async {
                folder = CDFolder.folder(id: Int32(selectedFeed))
                folderName = folder?.name ?? "Untitled"
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .symbolVariant(.circle.fill)
                        .foregroundStyle(Color(white: 0.50), .white, Color(white: 0.88))
                }
            }
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
                    } catch(let error as PBHError) {
                        switch error {
                        case .networkError(let message):
                            footerLabel = message
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
}

struct FolderRenameView_Previews: PreviewProvider {
    static var previews: some View {
        FolderRenameView(selectedFeed: .constant(0))
    }
}
