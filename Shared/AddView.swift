//
//  AddView.swift
//  AddView
//
//  Created by Peter Hedlund on 7/22/21.
//

import SwiftUI

enum AddType: Int, Identifiable {
    case feed
    case folder

    var id: Int { self.rawValue }
}

struct AddView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedAdd: AddType = .feed
    @State private var input = ""
    @State private var isAdding = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    @State private var folderSelection = noFolderName
    @State private var folderNames = [String]()
    @State private var folderId = 0

    init(_ selectedAddType: AddType) {
        self._selectedAdd = State(initialValue: selectedAddType)
    }

    var body: some View {
        VStack {
            Form {
                Section {
#if !os(macOS)
                    Picker("Add", selection: $selectedAdd) {
                        Text("Feed").tag(AddType.feed)
                        Text("Folder").tag(AddType.folder)
                    }
                    .pickerStyle(.segmented)
#endif
                    AddViewSegment(input: $input, addType: selectedAdd)
                    if selectedAdd == .feed {
                        Picker("Folder", selection: $folderSelection) {
                            ForEach(folderNames, id: \.self) {
                                Text($0)
                            }
                            .navigationTitle("Folder")
                        }
                        .disabled(input.isEmpty)
                    }
                    HStack {
                        Button {
                            switch selectedAdd {
                            case .feed:
                                Task {
                                    isAdding = true
                                    do {
                                        try await NewsManager.shared.addFeed(url: input, folderId: folderId)
                                        footerMessage = "Feed '\(input)' added"
                                        footerSuccess = true
                                    } catch(let error as PBHError) {
                                        switch error {
                                        case .networkError(let message):
                                            footerMessage = message
                                            footerSuccess = false
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
                                        footerMessage = "Folder '\(input)' added"
                                        footerSuccess = true
                                    } catch(let error as PBHError) {
                                        switch error {
                                        case .networkError(let message):
                                            footerMessage = message
                                            footerSuccess = false
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
                        .buttonStyle(.bordered)
                        .disabled(input.isEmpty)
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .opacity(isAdding ? 1.0 : 0.0)
#if os(macOS)
                            .controlSize(.small)
#endif
                    }
                } footer: {
                    FooterLabel(message: footerMessage, success: footerSuccess)
                }
            }
            .formStyle(.grouped)
#if os(macOS)
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
#endif
        }
#if os(iOS)
        .navigationTitle("Add Feed or Folder")
#endif
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
        AddView(.feed)
    }
}

struct AddViewSegment: View {
    @Binding var input: String
    var addType: AddType
    
    @ViewBuilder
    var body: some View {
        switch addType {
        case .feed:
            TextField("URL", text: $input, prompt: Text("https://example.com/feed"))
#if !os(macOS)
                .autocapitalization(.none)
                .textContentType(.URL)
                .listRowSeparator(.hidden)
#endif
                .disableAutocorrection(true)
                .textFieldStyle(.roundedBorder)
                .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        case .folder:
            TextField("Name", text: $input, prompt: Text("Folder Name"))
                .textFieldStyle(.roundedBorder)
                .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
#if !os(macOS)
                .listRowSeparator(.hidden)
#endif
        }
    }
}
