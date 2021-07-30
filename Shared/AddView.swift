//
//  AddView.swift
//  AddView
//
//  Created by Peter Hedlund on 7/22/21.
//

import SwiftUI
import CustomModalView

enum AddType: Int {
    case feed
    case folder
}

struct AddView: View {
    @Environment(\.modalPresentationMode) var modalPresentationMode: Binding<ModalPresentationMode>

    @State private var selectedAdd: AddType = .feed
    @State private var input = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                Picker("Add", selection: $selectedAdd) {
                    Text("Feed").tag(AddType.feed)
                    Text("Folder").tag(AddType.folder)
                }
                .pickerStyle(.segmented)
                AddViewSegment(input: $input, addType: selectedAdd)
            }
            .padding()
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Button(role: .cancel) {
                            self.modalPresentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Cancel")
                        }
                        .frame(width: 100)
                        Spacer()
                    }
                }
                Divider()
                VStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer()
                        Button {
                            switch selectedAdd {
                            case .feed:
                                Task {
                                    try await NewsManager.shared.addFeed(url: input)
                                }
                            case .folder:
                                Task {
                                    try await NewsManager.shared.addFolder(name: input)
                                }
                            }
                            self.modalPresentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Add")
                        }
                        .frame(width: 100)
                        Spacer()
                    }
                }
            }
            .frame(width: 280, height: 40)
        }
        .frame(width: 280)
        .padding(0)
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
        VStack(alignment: .leading, spacing: 4) {
            switch addType {
            case .feed:
                Text("Feed URL")
                TextField("", text: $input, prompt: Text("https://example.com/feed"))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textContentType(.URL)
                    .textFieldStyle(.roundedBorder)
            case .folder:
                Text("Folder Name")
                TextField("", text: $input, prompt: Text("Folder Name"))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
