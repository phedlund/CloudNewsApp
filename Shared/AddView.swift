//
//  AddView.swift
//  AddView
//
//  Created by Peter Hedlund on 7/22/21.
//

import SwiftUI

enum AddType: Int {
    case feed
    case folder
}

struct AddView: View {
    @State private var selectedAdd: AddType = .feed
    @State private var input = ""
    @State private var isAdding = false
    @State private var footerLabel = ""
    @State private var folderSelection = noFolderName
    @State private var folderNames = [String]()
    @State private var folderId = 0

    var body: some View {
        Form {
            Section(footer: Text(footerLabel)) {
                Picker("Add", selection: $selectedAdd) {
                    Text("Feed").tag(AddType.feed)
                    Text("Folder").tag(AddType.folder)
                }
                .pickerStyle(.segmented)
                AddViewSegment(input: $input, addType: selectedAdd)
                if selectedAdd == .feed {
                    Picker("Folder", selection: $folderSelection) {
                        ForEach(folderNames, id: \.self) {
                            Text($0)
                        }
                        .navigationTitle("Folder")
                    }
                }
                HStack {
                    Button {
                        switch selectedAdd {
                        case .feed:
                            Task {
                                isAdding = true
                                do {
                                    try await NewsManager.shared.addFeed(url: input, folderId: folderId)
                                    footerLabel = "Feed '\(input)' added"
                                } catch(let error as PBHError) {
                                    switch error {
                                    case .networkError(let message):
                                        footerLabel = message
                                    default:
                                        break
                                    }
                                }
                                isAdding = false
                            }
                        case .folder:
                            Task {
                                isAdding = true
                                do {
                                    try await NewsManager.shared.addFolder(name: input)
                                    footerLabel = "Folder '\(input)' added"
                                } catch(let error as PBHError) {
                                    switch error {
                                    case .networkError(let message):
                                        footerLabel = message
                                    default:
                                        break
                                    }
                                }
                                isAdding = false
                            }
                        }
                    } label: {
                        Text("Add")
                    }
                    .disabled(input.isEmpty)
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .opacity(isAdding ? 1.0 : 0.0)
                }
            }
        }
        .navigationTitle("Add Feed or Folder")
        .onAppear {
            if let folders = CDFolder.all() {
                var fNames = [noFolderName]
                let names = folders.compactMap( { $0.name } )
                fNames.append(contentsOf: names)
                folderNames = fNames
            }
        }
        .onChange(of: folderSelection) { [folderSelection] newFolder in
            if newFolder != folderSelection {
                if let newFolder = CDFolder.folder(name: newFolder) {
                    folderId = Int(newFolder.id)
                }
            }
        }
    }
}

struct AddView_Previews: PreviewProvider {
    static var previews: some View {
        AddView()
    }
}

struct AddViewSegment: View {
    @Binding var input: String
    var addType: AddType
    
    @ViewBuilder
    var body: some View {
        switch addType {
        case .feed:
            TextField("", text: $input, prompt: Text("https://example.com/feed"))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .textContentType(.URL)
                .textFieldStyle(.roundedBorder)
        case .folder:
            TextField("", text: $input, prompt: Text("Folder Name"))
                .textFieldStyle(.roundedBorder)
        }
    }
}
