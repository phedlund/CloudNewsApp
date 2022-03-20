//
//  SettingsView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 6/27/20.
//

enum KeepDuration: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case twelve = 12

    var id: Int { self.rawValue }
}

enum SettingsSheet {
    case login
    case add
    case mail
}

extension SettingsSheet: Identifiable {
    var id: SettingsSheet { self }
}

#if !os(macOS)
import MessageUI
#endif
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    @Binding var showModal: Bool
    @State var isShowingMailView = false
    
    var body: some View {
#if os(macOS)
        SettingsForm()
#else
        SettingsForm()
            .listStyle(GroupedListStyle())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showModal = false
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .symbolVariant(.circle.fill)
                            .foregroundStyle(Color(white: 0.50), .white, Color(white: 0.88))
                    }
                }
            }
#endif
    }

}
    
struct SettingsForm: View {
    @Environment(\.openURL) var openURL

    @AppStorage(StorageKeys.server) var server = ""
    @AppStorage(StorageKeys.syncOnStart) var syncOnStart = false
    @AppStorage(StorageKeys.syncInBackground) var syncInBackground = false
    @AppStorage(StorageKeys.productName) var productName = ""
    @AppStorage(StorageKeys.productVersion) var productVersion = ""
    @AppStorage(StorageKeys.newsVersion) var newsVersion = ""
    @AppStorage(StorageKeys.showFavIcons) var showFavIcons = true
    @AppStorage(StorageKeys.showThumbnails) var showThumbnails = true
    @AppStorage(StorageKeys.markReadWhileScrolling) var markReadWhileScrolling = true
    @AppStorage(StorageKeys.sortOldestFirst) var sortOldestFirst = false
    @AppStorage(StorageKeys.compactView) var compactView = false
    @AppStorage(StorageKeys.keepDuration) var keepDuration: KeepDuration = .three
    
    @State private var isShowingMailView = false
    @State private var isShowingSheet = false
    @State private var footerMessage = ""
    @State private var preferences = Preferences()
    @State private var settingsSheet: SettingsSheet?
    @State private var currentSettingsSheet: SettingsSheet = .login

    private let email = "support@pbh.dev"
    private let subject = NSLocalizedString("CloudNotes Support Request", comment: "Support email subject")
    private let message = NSLocalizedString("<Please state your question or problem here>", comment: "Support email body placeholder")

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
            Section(header: Text("Server"), footer: Text(footerMessage)) {
                TextField("https://example.com/cloud", text: $server)
#if !os(macOS)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .listRowSeparator(.hidden)
                    .textFieldStyle(.roundedBorder)
#endif
                Button {
                    currentSettingsSheet = .login
                    settingsSheet = .login
                    isShowingSheet = true
                } label: {
                    Text("Log In")
                }
                .buttonStyle(.bordered)
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
                Toggle(isOn: $preferences.hideRead) {
                    Text("Hide Read Items")
                }
                Toggle(isOn: $sortOldestFirst) {
                    Text("Sort Oldest Item First")
                }
                Toggle(isOn: $compactView) {
                    Text("Comapct View")
                }
            }
            Section(header: Text("Maintenance")) {
                Picker("Keep Articles For", selection: $keepDuration) {
                    Text("1 month").tag(KeepDuration.one)
                    Text("3 months").tag(KeepDuration.three)
                    Text("12 months").tag(KeepDuration.twelve)
                        .navigationTitle("Duration")
                }
                NavigationLink("Add Feed or Folder...") {
                    AddView()
                }
            }
            Section(header: Text("Support")) {
                Button {
                    sendMail()
                } label: {
                    Label("Contact", systemImage: "mail")
                }
            }
#endif
        }
        .onAppear(perform: {
            updateFooter()
        })
        .sheet(item: $settingsSheet,
               onDismiss: { onDismiss() },
               content: { sheet in
            switch sheet {
            case .add:
                NavigationView {
                    AddView()
                }
            case .login:
                LoginWebViewView(server: server)
            case .mail:
                MailComposeView(recipients: [email], subject: subject, message: message) {
                    // Did finish action
                }
            }
        })
    }

    private func onDismiss() {
        print($currentSettingsSheet.wrappedValue)
        switch currentSettingsSheet {
        case .login:
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
        case .add, .mail:
            break
        }
        settingsSheet = nil
        isShowingSheet = false
    }

    private func updateFooter() {
        guard !productName.isEmpty,
              !productVersion.isEmpty
        else {
            footerMessage = NSLocalizedString("Not logged in", comment: "Message about not being logged in")
            return
        }
        let newsVersionString = newsVersion.isEmpty ? "" : "\(newsVersion) "
        let format = NSLocalizedString("Using News %@on %@ %@.", comment:"Message with News version, product name and version")
        footerMessage = String.localizedStringWithFormat(format, newsVersionString, productName, productVersion)
    }
    
    private func sendMail() {
        if MFMailComposeViewController.canSendMail() {
            settingsSheet = .mail
            isShowingMailView = true
        } else {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = email
            components.queryItems = [URLQueryItem(name: "subject", value: subject),
                                     URLQueryItem(name: "body", value: message)]
            if let mailURL = components.url {
                openURL(mailURL)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showModal: .constant(true))
    }
}
