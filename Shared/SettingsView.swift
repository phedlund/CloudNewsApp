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
    @State var isShowingMailView = false
    
    var body: some View {
#if os(macOS)
        SettingsForm()
            .listStyle(.plain)
            .navigationTitle("Settings")
#else
        SettingsForm()
            .listStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
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
    @State private var footerSuccess = true
    @State private var preferences = Preferences()
    @State private var settingsSheet: SettingsSheet?
    @State private var currentSettingsSheet: SettingsSheet = .login

    private let email = "support@pbh.dev"
    private let subject = NSLocalizedString("CloudNotes Support Request", comment: "Support email subject")
    private let message = NSLocalizedString("<Please state your question or problem here>", comment: "Support email body placeholder")

    var body: some View {
        Form {
            Section {
                TextField(text: $server, prompt: Text("https://example.com/cloud")) {
                    Text("URL")
                }
#if !os(macOS)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .listRowSeparator(.hidden)
#endif
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                Button {
#if !os(macOS)
                    currentSettingsSheet = .login
                    settingsSheet = .login
                    isShowingSheet = true
#else
                    if let url = URL(string: "cloudnews://login") {
                        openURL(url)
                    }
#endif
                } label: {
                    Text("Log In")
                }
                .buttonStyle(.bordered)
                .disabled(server.isEmpty)
            }
            .groupedStyle(header: Text("Server"), footer: FooterLabel(message: footerMessage, success: footerSuccess))

            Section {
                Toggle(isOn: $syncOnStart) {
                    Text("Sync on Start")
                }
                Toggle(isOn: $syncInBackground) {
                    Text("Sync in Background")
                }
            }
            .groupedStyle(header: Text("Syncing"))

            Section {
                Toggle(isOn: $showFavIcons) {
                    Text("Show Favicons")
                }
                Toggle(isOn: $showThumbnails) {
                    Text("Show Thumbnails")
                }
            }
            .groupedStyle(header: Text("Images"))

            Section() {
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
            .groupedStyle(header: Text("Reading"))

            Section() {
                Picker("Keep Articles For", selection: $keepDuration) {
                    Text("1 month").tag(KeepDuration.one)
                    Text("3 months").tag(KeepDuration.three)
                    Text("12 months").tag(KeepDuration.twelve)
                        .navigationTitle("Duration")
                }
                NavigationLink {
                    AddView()
                } label: {
                    Text("Add Feed or Folder...")
                }
            }
            .groupedStyle(header: Text("Maintenance"))

            Section {
                Button {
                    sendMail()
                } label: {
                    Label("Contact", systemImage: "mail")
                }
            }
            .groupedStyle(header: Text("Support"))

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
                LoginWebViewView()
            case .mail:
#if !os(macOS)
                MailComposeView(recipients: [email], subject: subject, message: message) {
                    // Did finish action
                }
#else
                EmptyView() //todo
#endif
            }
        })
        .onReceive(NotificationCenter.default.publisher(for: .loginComplete)) { _ in
            currentSettingsSheet = .login
            onDismiss()
        }
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
            footerSuccess = false
            return
        }
        let newsVersionString = newsVersion.isEmpty ? "" : "\(newsVersion) "
        let format = NSLocalizedString("Using News %@on %@ %@.", comment:"Message with News version, product name and version")
        footerMessage = String.localizedStringWithFormat(format, newsVersionString, productName, productVersion)
        footerSuccess = true
    }
    
    private func sendMail() {
#if !os(macOS)
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
#endif
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

extension View {
    func groupedStyle<V: View>(header: V = EmptyView() as! V, footer: FooterLabel = FooterLabel(message: "", success: true) ) -> some View {
#if os(iOS)
        return Section(header: header, footer: footer) {
            self
        }
#else
        return VStack(alignment: .leading) {
            GroupBox(label: header
                .font(.bold(.body)())
                .padding(.top, 3)
                .padding(.bottom, 3)) {
                    HStack {
                        VStack(alignment: .leading) {
                            self.padding(.vertical, 3)
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            Spacer()
            footer.foregroundColor(.secondary)
        }
#endif
    }
}
