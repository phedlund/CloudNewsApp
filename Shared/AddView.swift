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
    
    var body: some View {
        Form {
            Picker("Add", selection: $selectedAdd) {
                Text("Feed").tag(AddType.feed)
                Text("Folder").tag(AddType.folder)
            }
            .pickerStyle(.segmented)
            AddViewSegment(input: $input, addType: selectedAdd)
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
            } label: {
                Text("Add")
            }
        }
        .navigationTitle("Add Feed or Folder")
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
