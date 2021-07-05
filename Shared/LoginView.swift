//
//  LoginView.swift
//  CloudNotes
//
//  Created by Peter Hedlund on 6/27/20.
//

import SwiftUI

struct LoginView: View {
    @Binding var showModal: Bool
    
    var body: some View {
        LoginForm()
#if !os(macOS)
            .listStyle(GroupedListStyle())
            .navigationTitle("Login Information")
#endif
    }
}

struct LoginForm: View {
    @AppStorage(StorageKeys.server) var server: String = ""
    @AppStorage(StorageKeys.isLoggedIn) var isLoggedIn: Bool = false
    @AppStorage(StorageKeys.allowUntrustedCertificate) var allowUntrustedCertificate: Bool = false
    @AppStorage(StorageKeys.productVersion) var productVersion: String = ""
    @AppStorage(StorageKeys.productName) var productName: String = ""
    @AppStorage(StorageKeys.newsVersion) var newsVersion: String = ""
    @AppStorage(StorageKeys.notesApiVersion) var notesApiVersion: String = ""
    @KeychainStorage(StorageKeys.username) var username: String = ""
    @KeychainStorage(StorageKeys.password) var password: String = ""

    @State private var footerLabel = ""
    @State private var opacity = 0.0
    @State private var showingAlert = false
//    @State private var errorMessage = ErrorMessage(title: "", body: "")

    var body: some View {
        #if os(macOS)
        let headerView = EmptyView()
        #else
        let headerView = Text("Server")
        #endif
        Form {
            Section(header: headerView) {
                VStack(alignment: .leading) {
                    Text("Address")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    TextField("https://example.com/cloud", text: $server)
#if !os(macOS)
                        .textContentType(.URL)
                        .autocapitalization(.none)
#endif
                }
                VStack(alignment: .leading) {
                    Text("Username")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    TextField("username", text: $username)
                        .textContentType(.username)
#if !os(macOS)
                        .autocapitalization(.none)
#endif
                }
                VStack(alignment: .leading) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    SecureField("password", text: $password)
                        .textContentType(.password)
#if !os(macOS)
                        .autocapitalization(.none)
#endif
                }
                Toggle(isOn: $allowUntrustedCertificate) {
                    Text("Allow Untrusted SSL Certificate")
                }
            }
            Section(footer: Text(footerLabel)) {
                HStack {
                    Spacer()
                    Button("Connect") {
                        async {
                            await login()
                        }
                    }
                    Spacer()
                    ProgressView()
                        .opacity(opacity)
                }
                .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            updateFooter()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error" /*errorMessage.title*/), message: Text("Error Message" /*errorMessage.body*/), dismissButton: .cancel())
        }
    }
    
    private func login() async {
        opacity = 1.0
        var serverAddress = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
           !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        server = serverAddress
        
        do {
            let status = try await NewsManager.shared.status()
            productName = status.name
            productVersion = status.version
            
            newsVersion = try await NewsManager.shared.version()
            self.isLoggedIn = true
            opacity = 0.0
            updateFooter()
        } catch {
            productName = ""
            productVersion = ""
            opacity = 0.0
            updateFooter()
//            showErrorMessage(message: error.message)
        
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
    
//    private func showErrorMessage(message: ErrorMessage) {
//        errorMessage = message
//        showingAlert = true
//    }

}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(showModal: .constant(true))
    }
}
