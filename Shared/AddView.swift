//
//  AddView.swift
//  AddView
//
//  Created by Peter Hedlund on 7/22/21.
//

import SwiftData
import SwiftUI

enum AddType: Int, Identifiable {
    case feed
    case folder

    var id: Int { self.rawValue }
}

struct AddView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NewsModel.self) private var newsModel
    @Environment(\.modelContext) private var modelContext

    var selectedAdd: AddType
    
    @State private var input = ""
    @State private var isAdding = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    @State private var folderSelection = noFolderName
    @State private var folderNames = [String]()
    @State private var folderId = 0

    @Query private var folders: [Folder]

    var body: some View {
        VStack {
            Form {
                Section {
                    AddViewSegment(input: $input, addType: selectedAdd)
                    if selectedAdd == .feed {
                        Picker(selection: $folderSelection) {
                            ForEach(folderNames, id: \.self) {
                                Text($0)
                            }
                            .navigationTitle("Folder")
                        } label: {
                            Text("Folder")
                        }
                        .disabled(input.isEmpty)
                    }
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .opacity(isAdding ? 1.0 : 0.0)
                        Button {
                            switch selectedAdd {
                            case .feed:
                                Task {
                                    isAdding = true
                                    do {
                                        try await newsModel.addFeed(url: input, folderId: folderId)
                                        footerMessage = "Feed '\(input)' added"
                                        footerSuccess = true
                                    } catch let error as NetworkError {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    } catch let error as DatabaseError {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    } catch let error {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    }
                                    isAdding = false
                                }
                            case .folder:
                                Task {
                                    isAdding = true
                                    do {
                                        try await newsModel.addFolder(name: input)
                                        footerMessage = "Folder '\(input)' added"
                                        footerSuccess = true
                                    } catch let error as NetworkError {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    } catch let error as DatabaseError {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    } catch let error {
                                        footerMessage = error.localizedDescription
                                        footerSuccess = false
                                    }
                                    isAdding = false
                                }
                            }
                        } label: {
                            Text("Add")
                                .padding(.horizontal)
                        }
                        .foregroundStyle(.phWhiteIcon)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle)
                        .disabled(input.isEmpty)
#if os(macOS)
                            .controlSize(.small)
#endif
                    }
                } footer: {
                    FooterLabel(message: footerMessage, success: footerSuccess)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
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
        .navigationTitle( selectedAdd == .feed ? "Add Feed" : "Add Folder")
#endif
        .onAppear {
            var fNames = [noFolderName]
            let names = folders.compactMap( { $0.name } ).sorted()
            fNames.append(contentsOf: names)
            folderNames = fNames
        }
        .onChange(of: folderSelection, { oldValue, newValue in
            if newValue != oldValue {
                if let newFolder = folders.first(where: { $0.name == newValue }) {
                    folderId = Int(newFolder.id)
                }
            }

        })
    }
}

struct AddView_Previews: PreviewProvider {
    static var previews: some View {
        AddView(selectedAdd: .feed)
    }
}

struct AddViewSegment: View {
    @Binding var input: String
    var addType: AddType
    
    @ViewBuilder
    var body: some View {
        switch addType {
        case .feed:
            TextField("URL", text: $input, prompt: Text(verbatim: "https://example.com/feed"))
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
