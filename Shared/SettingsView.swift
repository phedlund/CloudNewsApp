//
//  SettingsView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 6/27/20.
//

enum SyncInterval: Int, CaseIterable, Identifiable {
    case zero = 0
    case fifteen = 900
    case thirty = 1800
    case sixty = 3600

    var id: Int { self.rawValue }
}

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
    case certificate
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
#if os(macOS)
    @Environment(\.openWindow) var openWindow
#else
    @Environment(\.openURL) var openURL
#endif
    @AppStorage(StorageKeys.server) var server = ""
    @AppStorage(StorageKeys.allowUntrustedCertificate) var allowUntrustedCertificate = false
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
    @AppStorage(StorageKeys.syncInterval) var syncInterval: SyncInterval = .fifteen
    @AppStorage(StorageKeys.adBlock) var adBlock = true

    @State private var isShowingMailView = false
    @State private var isShowingSheet = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    @State private var preferences = Preferences()
    @State private var settingsSheet: SettingsSheet?
    @State private var currentSettingsSheet: SettingsSheet = .login
    @State private var isShowingCertificateAlert = false

    private let email = "support@pbh.dev"
    private let subject = NSLocalizedString("CloudNews Support Request", comment: "Support email subject")
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
                    onLogin()
                } label: {
                    Text("Log In")
                }
                .buttonStyle(.bordered)
                .disabled(server.isEmpty)

            } header: {
                Text("Server")
            } footer: {
                FooterLabel(message: footerMessage, success: footerSuccess)
            }
            Section {
#if !os(macOS)
                Toggle(isOn: $syncOnStart) {
                    Text("Sync on Start")
                }
                Toggle(isOn: $syncInBackground) {
                    Text("Sync in Background")
                }
#else
                Picker("Sync Every", selection: $syncInterval) {
                    Text("Never").tag(SyncInterval.zero)
                    Text("15 minutes").tag(SyncInterval.fifteen)
                    Text("30 minutes").tag(SyncInterval.thirty)
                    Text("60 minutes").tag(SyncInterval.sixty)
                        .navigationTitle("Sync Interval")
                }
#endif
            } header: {
                Text("Syncing")
            }
            Section {
                Toggle(isOn: $showFavIcons) {
                    Text("Show Favicons")
                }
                Toggle(isOn: $showThumbnails) {
                    Text("Show Thumbnails")
                }
            } header: {
                Text("Images")
            }
            Section {
                Toggle(isOn: $markReadWhileScrolling) {
                    Text("Mark Items Read While Scrolling")
                }
                Toggle(isOn: $compactView) {
                    Text("Comapct View")
                }
                Toggle(isOn: $preferences.hideRead) {
                    Text("Hide Read Items")
                }
                Toggle(isOn: $sortOldestFirst) {
                    Text("Sort Oldest Item First")
                }
                Toggle(isOn: $adBlock) {
                    Text("Block Ads")
                    Text("CloudNews uses a block list from the [Brave project](https://github.com/brave/brave-ios/blob/development/Client/WebFilters/ContentBlocker/Lists/block-ads.json)")
                }
            } header: {
                Text("Reading")
            }
            Section {
                Picker(selection: $keepDuration) {
                    Text("1 month").tag(KeepDuration.one)
                    Text("3 months").tag(KeepDuration.three)
                    Text("12 months").tag(KeepDuration.twelve)
                        .navigationTitle("Duration")
                } label: {
                    Text("Keep Articles For")
                    Text("Starred articles will never be deleted")
                }
#if !os(macOS)
                NavigationLink {
                    AddView(.feed)
                } label: {
                    Text("Add Feed or Folder...")
                }
#endif
            } header: {
                Text("Maintenance")
            }
            Section {
#if !os(macOS)
                Button {
                    sendMail()
                } label: {
                    Label("Contact", systemImage: "mail")
                }
#else
                Link(destination: supportURL) {
                    Label("Email", systemImage: "mail")
                }
#endif
                Link(destination: URL(string: "https://pbh.dev/cloudnews")!) {
                    Label("Web Site", systemImage: "link")
                }

            } header: {
                Text("Support")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            updateFooter()
        }
        .sheet(item: $settingsSheet,
               onDismiss: { onDismiss() },
               content: { sheet in
            switch sheet {
            case .add:
                NavigationView {
                    AddView(.feed)
                }
            case .login:
                LoginWebViewView()
            case .certificate:
                if let host = URL(string: server)?.host {
                    NavigationView {
                        CertificateView(host: host)
                    }
                } else {
                    EmptyView()
                }
            case .mail:
#if !os(macOS)
                MailComposeView(recipients: [email], subject: subject, message: message) {
                    // Did finish action
                }
#else
                EmptyView()
#endif
            }
        })
        .alert(Text("The certificate for this server is invalid"), isPresented: $isShowingCertificateAlert, actions: {
            Button {
                if let host = URL(string: server)?.host {
                    ServerStatus.shared.writeCertificate(host: host)
                    allowUntrustedCertificate = true
                    currentSettingsSheet = .login
                    settingsSheet = .login
                    isShowingSheet = true
                }
                isShowingCertificateAlert = false
            } label: {
                Text("Yes")
            }
            Button {
                allowUntrustedCertificate = false
                isShowingCertificateAlert = false
            } label: {
                Text("No")
            }
            Button {
                currentSettingsSheet = .certificate
                settingsSheet = .certificate
                isShowingSheet = true
                allowUntrustedCertificate = false
                isShowingCertificateAlert = false
            } label: {
                Text("View Certificate")
            }
        }, message: {
            Text("Do you want to connect to the server anyway?")
        })
        .onReceive(NotificationCenter.default.publisher(for: .loginComplete)) { _ in
            currentSettingsSheet = .login
            onDismiss()
        }
#if !os(macOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .symbolVariant(.circle.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
            }
        }
#endif
    }

    private func onDismiss() {
        print($currentSettingsSheet.wrappedValue)
        switch currentSettingsSheet {
        case .login:
            Task {
                do {
                    newsVersion = try await NewsManager.shared.version()
                    updateFooter()
                } catch {
                    productName = ""
                    productVersion = ""
                    updateFooter()
                }
            }
        case .add, .mail, .certificate:
            break
        }
        settingsSheet = nil
        isShowingSheet = false
    }

    private func onLogin() {
        ServerStatus.shared.reset()
        Task { @MainActor in
            do {
                let status = try await ServerStatus.shared.check()
                productName = status?.name ?? ""
                productVersion = status?.version ?? ""
#if !os(macOS)
                currentSettingsSheet = .login
                settingsSheet = .login
                isShowingSheet = true
#else
                openWindow(id: "login")
#endif
            } catch (let error as NSError) {
                print(error.localizedDescription)
                if error.code == NSURLErrorServerCertificateUntrusted {
                    isShowingCertificateAlert = true
                } else {
                    //                let alertController = UIAlertController(title: NSLocalizedString("Connection error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    //                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { _ in }))
                    //                self.present(alertController, animated: true, completion: { })
                }
            }
        }
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
    
#if !os(macOS)
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
#else
    var supportURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [URLQueryItem(name: "subject", value: subject),
                                 URLQueryItem(name: "body", value: message)]
        if let mailURL = components.url {
            return mailURL
        } else {
            return URL(string: "data:null")!
        }
    }
#endif

}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
