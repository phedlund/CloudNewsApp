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
    @EnvironmentObject private var nodeTree: FeedTreeModel
    @AppStorage(StorageKeys.server) var server: String = ""
    @AppStorage(StorageKeys.isLoggedIn) var isLoggedIn: Bool = false
    @AppStorage(StorageKeys.syncOnStart) var syncOnStart: Bool = false
    @AppStorage(StorageKeys.syncInBackground) var syncInBackground: Bool = false
    @AppStorage(StorageKeys.productName) var productName: String = ""
    @AppStorage(StorageKeys.productVersion) var productVersion: String = ""
    @AppStorage(StorageKeys.newsVersion) var newsVersion: String = ""
    @AppStorage(StorageKeys.showFavIcons) var showFavIcons: Bool = true
    @AppStorage(StorageKeys.showThumbnails) var showThumbnails: Bool = true
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling: Bool = true
    @AppStorage(StorageKeys.sortOldestFirst) var sortOldestFirst: Bool = false
    @AppStorage(StorageKeys.compactView) var compactView: Bool = false
    @State var isShowingMailView = false
    @State var isShowingLogIn = false
    @State private var footerLabel = "Hey, I am the footer"

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
            Section(header: Text("Server"), footer: Text(footerLabel)) {
                TextField("https://example.com/cloud", text: $server)
#if !os(macOS)
                    .textContentType(.URL)
                    .autocapitalization(.none)
#endif
                Button {
                    isShowingLogIn = true
                } label: {
                    Text("Log In")
                }
                .disabled(server.isEmpty)
            }
            Section(header: Text("Syncing")) {
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
                Toggle(isOn: $nodeTree.preferences.hideRead) {
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
        .onAppear(perform: {
            updateFooter()
        })
        .sheet(isPresented: $isShowingLogIn) {
            Task {
                do {
                    let status = try await NewsManager.shared.status()
                    productName = status.name
                    productVersion = status.version
                    newsVersion = try await NewsManager.shared.version()
                    updateFooter()
                } catch {
                    productName = ""
                    productVersion = ""
                    updateFooter()
                }
            }
            isShowingLogIn = false
        } content: {
            LoginWebViewView(server: server)
        }
    }

    private func updateFooter() {
        guard !productName.isEmpty,
              !productVersion.isEmpty
        else {
            footerLabel = NSLocalizedString("Not logged in", comment: "Message about not being logged in")
            return
        }
        let newsVersionString = newsVersion.isEmpty ? "" : "\(newsVersion) "
        let format = NSLocalizedString("Using News %@on %@ %@.", comment:"Message with News version, product name and version")
        footerLabel = String.localizedStringWithFormat(format, newsVersionString, productName, productVersion)
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showModal: .constant(true))
    }
}
