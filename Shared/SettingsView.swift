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
    @Environment(NewsModel.self) private var newsModel
#if os(macOS)
    @Environment(\.openWindow) var openWindow
#else
    @Environment(\.openURL) var openURL
#endif
    @AppStorage(SettingKeys.server) var server = ""
    @AppStorage(SettingKeys.allowUntrustedCertificate) var allowUntrustedCertificate = false
    @AppStorage(SettingKeys.syncOnStart) var syncOnStart = false
    @AppStorage(SettingKeys.syncInBackground) var syncInBackground = false
    @AppStorage(SettingKeys.productName) var productName = ""
    @AppStorage(SettingKeys.productVersion) var productVersion = ""
    @AppStorage(SettingKeys.newsVersion) var newsVersion = ""
    @AppStorage(SettingKeys.showFavIcons) var showFavIcons = true
    @AppStorage(SettingKeys.showThumbnails) var showThumbnails = true
    @AppStorage(SettingKeys.markReadWhileScrolling) var markReadWhileScrolling = true
    @AppStorage(SettingKeys.sortOldestFirst) var sortOldestFirst = false
    @AppStorage(SettingKeys.compactView) var compactView = false
    @AppStorage(SettingKeys.keepDuration) var keepDuration: KeepDuration = .three
    @AppStorage(SettingKeys.syncInterval) var syncInterval: SyncInterval = .fifteen
    @AppStorage(SettingKeys.adBlock) var adBlock = true
    @AppStorage(SettingKeys.hideRead) private var hideRead = false
    @AppStorage(SettingKeys.isNewInstall) private var isNewInstall = true
    @AppStorage(SettingKeys.selectedNodeModel) private var selectedNode: Data?

    @State private var isShowingMailView = false
    @State private var isShowingSheet = false
    @State private var isShowingConfirmation = false
    @State private var footerMessage = ""
    @State private var footerSuccess = true
    @State private var settingsSheet: SettingsSheet?
    @State private var currentSettingsSheet: SettingsSheet = .login
    @State private var isShowingCertificateAlert = false
    @State private var isShowingConnectionError = false

    var body: some View {
        Form {
            Section {
                    TextField(text: $server, prompt: Text(verbatim: "https://example.com/cloud")) {
                        Text("URL")
                    }
                    .textContentType(.URL)
                    .listRowSeparator(.hidden)
#if !os(macOS)
                    .autocapitalization(.none)
#endif
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                HStack {
                    Spacer()
                    Button {
                        onLogin()
                    } label: {
                        Text("Log In...")
                            .padding(.horizontal)
                    }
                    .foregroundStyle(.phWhiteIcon)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .disabled(server.isEmpty)
                }
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
                Picker(selection: $syncInterval) {
                    Text("Never").tag(SyncInterval.zero)
                    Text("15 minutes").tag(SyncInterval.fifteen)
                    Text("30 minutes").tag(SyncInterval.thirty)
                    Text("60 minutes").tag(SyncInterval.sixty)
                        .navigationTitle("Sync Interval")
                } label: {
                    Text("Sync Every")
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
#if !os(macOS)
                Toggle(isOn: $markReadWhileScrolling) {
                    Text("Mark Items Read While Scrolling")
                }
#endif
                Toggle(isOn: $compactView) {
                    Text("Comapct View")
                }
                Toggle(isOn: $hideRead) {
                    Text("Hide Read Items")
                }
                Toggle(isOn: $sortOldestFirst) {
                    Text("Sort Oldest Item First")
                }
                Toggle(isOn: $adBlock) {
                    Text("Block Ads")
                    Text("CloudNews uses a block list from the [Brave project](https://github.com/brave/brave-core/blob/master/ios/brave-ios/Sources/Brave/WebFilters/ContentBlocker/Lists/block-ads.json)")
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
                    AddView(selectedAdd: .feed)
                } label: {
                    Text("Add Feed...")
                }
                NavigationLink {
                    AddView(selectedAdd: .folder)
                } label: {
                    Text("Add Folder...")
                }
#endif
                Button(role: .destructive) {
                    isShowingConfirmation = true
                } label: {
                    Text("Reset Local Data")
                }
                .buttonStyle(.plain)
            } header: {
                Text("Maintenance")
            }
#if !os(macOS)
            Section {
                Button {
                    sendMail()
                } label: {
                    Label("Contact", systemImage: "mail")
                }
                Link(destination: URL(string: Constants.website)!) {
                    Label("Web Site", systemImage: "link")
                }
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Text("Acknowledgements...")
                }

            } header: {
                Text("Support")
            }
            .tint(.accent)
#endif
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
                    AddView(selectedAdd: .feed)
                }
            case .login:
                LoginView()
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
                MailComposeView(recipients: [Constants.email],
                                subject: Constants.subject,
                                message: Constants.message) {
                    // Did finish action
                }
#else
                EmptyView()
#endif
            }
        })
        .alert("The certificate for this server is invalid", isPresented: $isShowingCertificateAlert, actions: {
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
        .alert("Connection Error", isPresented: $isShowingConnectionError, actions: {
            Button {
                isShowingConnectionError = false
            } label: {
                Text("OK")
            }
        })
        .confirmationDialog("Clear local data", isPresented: $isShowingConfirmation, actions: {
            Button("Reset Data", role: .destructive) {
                Task {
                    do {
                        try await newsModel.resetDataBase()
                        server = ""
                        productName = ""
                        productVersion = ""
                        isNewInstall = true
                        selectedNode = nil
                        updateFooter()
                    } catch {
                        //
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                isShowingConfirmation = false
            }
        }, message: {
            Text("Do you want to remove all feeds and articles from this device? You will also be signed out.")
        })
        .onReceive(NotificationCenter.default.publisher(for: .loginComplete)) { _ in
            currentSettingsSheet = .login
            onDismiss()
        }
#if !os(macOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    dismiss()
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
                    let status = try await ServerStatus.shared.check()
                    productName = status?.name ?? ""
                    productVersion = status?.version ?? ""
                    newsVersion = try await newsModel.version()
                    updateFooter()
                    isNewInstall = false
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
                    isShowingConnectionError = true
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
            components.path = Constants.email
            components.queryItems = [URLQueryItem(name: "subject", value: Constants.subject),
                                     URLQueryItem(name: "body", value: Constants.message)]
            if let mailURL = components.url {
                openURL(mailURL)
            }
        }
    }
#endif
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
