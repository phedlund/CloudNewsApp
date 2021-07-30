//
//  SettingsView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 6/27/20.
//

#if !os(macOS)
import MessageUI
#endif
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var showModal: Bool
#if !os(macOS)
    @State var result: Result<MFMailComposeResult, Error>? = nil
#endif
    @State var isShowingMailView = false
    
    var body: some View {
#if os(macOS)
        SettingsForm()
#else
        SettingsForm()
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarItems(trailing:
                                    Button(action: {
                showModal = false
                dismiss()
            }, label: {
                Text("Done")
            }))
#endif
    }

}
    
struct SettingsForm: View {
    @AppStorage(StorageKeys.syncOnStart) var syncOnStart: Bool = false
    @AppStorage(StorageKeys.syncInBackground) var syncInBackground: Bool = false
    @AppStorage(StorageKeys.productName) var productName: String = ""
    @AppStorage(StorageKeys.productVersion) var productVersion: String = ""
    @AppStorage(StorageKeys.showFavIcons) var showFavIcons: Bool = true
    @AppStorage(StorageKeys.showThumbnails) var showThumbnails: Bool = true
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @AppStorage(StorageKeys.hideRead) var hideRead: Bool = false
    @AppStorage(StorageKeys.sortOldestFirst) var sortOldestFirst: Bool = false
    @AppStorage(StorageKeys.compactView) var compactView: Bool = false
    @State var isShowingMailView = false

    var body: some View {
        Form {
            #if os(macOS)
            Toggle(isOn: $syncOnStart) {
                Text("Sync on Start")
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, idealHeight: 20, maxHeight: 20, alignment: .leading)
            Toggle(isOn: $offlineMode) {
                Text("Work Offline")
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, idealHeight: 20, maxHeight: 20, alignment: .leading)
            Color(NSColor.clear)
            #else
            Section(header: Text("Syncing")) {
                NavigationLink(destination: LoginView(showModal: .constant(false))) {
                    HStack {
                        Text("Server")
                        Spacer()
                        Text(productName.isEmpty || productVersion.isEmpty ? "Not logged in" : "Logged in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $syncOnStart) {
                    Text("Sync on Start")
                }
                Toggle(isOn: $syncInBackground) {
                    Text("Sync in Background")
                }
            }
            Section(header: Text("Images")) {
                Toggle(isOn: $showFavIcons) {
                    Text("Show Favicons")
                }
                Toggle(isOn: $showThumbnails) {
                    Text("Show Thumbnails")
                }
            }
            Section(header: Text("Reading")) {
                Toggle(isOn: $markReadWhileScrolling) {
                    Text("Mark Items Read While Scrolling")
                }
                Toggle(isOn: $hideRead) {
                    Text("Hide Read Items")
                }
                Toggle(isOn: $sortOldestFirst) {
                    Text("Sort Oldest Item First")
                }
                Toggle(isOn: $compactView) {
                    Text("Comapct View")
                }
            }
            Section(header: Text("Support")) {
                Label("Contact", systemImage: "mail")
////                    .onTapGesture {
////                        self.isShowingMailView = true
////                    }
//                    //                        .disabled(!MFMailComposeViewController.canSendMail())
//                    .sheet(isPresented: $isShowingMailView) {
//                        MailView(result: self.$result)
//                    }
            }
            #endif
        }
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showModal: .constant(true))
    }
}
