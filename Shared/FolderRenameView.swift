//
//  FolderRenameView.swift
//  FolderRenameView
//
//  Created by Peter Hedlund on 7/16/21.
//

import SwiftUI

struct FolderRenameView: View {
    @Binding var showModal: Bool
    @Binding var isRenaming: Bool
    @Binding var folderName: String

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
                //
            } label: {
                Text("Rename")
            }
        }
        .padding()
        .textFieldStyle(.roundedBorder)
        .buttonStyle(.bordered)
        .frame(width: 250, height: 200)
    }
}

struct FolderRenameView_Previews: PreviewProvider {
    static var previews: some View {
        FolderRenameView(showModal: .constant(true), isRenaming: .constant(false), folderName: .constant("My Folder"))
    }
}
