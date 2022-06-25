//
//  FolderRenameView.swift
//  FolderRenameView
//
//  Created by Peter Hedlund on 7/16/21.
//

import SwiftUI

struct FolderRenameView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var folderName = ""
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    
    private var folder: CDFolder?
    private var initialName = ""
    
    init(_ selectedFeed: Int) {
        if let theFolder = CDFolder.folder(id: Int32(selectedFeed)) {
            self.folder = theFolder
            initialName = theFolder.name ?? "Untitled"
            self._folderName = State(initialValue: initialName)
        }
    }
    
    var body: some View {
        VStack {
            Form {
                Section {
                    TextField("Name", text: $folderName)
                        .textFieldStyle(.roundedBorder)
                        .listRowSeparator(.hidden)
                    Button {
                        onSave()
                    } label: {
                        Text("Rename")
                    }
                    .buttonStyle(.bordered)
                    .disabled(folderName.isEmpty)
                } header: {
                    Text("Rename Folder")
                } footer: {
                    FooterLabel(message: footerMessage, success: footerSuccess)
                }
                .navigationTitle("Folder Name")
            }
            .formStyle(.grouped)
            .navigationTitle("Folder Name")
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
    
    private func onSave() {
        if let folder = folder {
            if folderName != initialName {
                Task {
                    do {
                        try await NewsManager.shared.renameFolder(folder: folder, to: folderName)
                        folder.name = folderName
                        try NewsData.mainThreadContext.save()
                        dismiss()
                    } catch(let error as PBHError) {
                        switch error {
                        case .networkError(let message):
                            folderName = initialName
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
}

struct FolderRenameView_Previews: PreviewProvider {
    static var previews: some View {
        FolderRenameView(0)
    }
}
