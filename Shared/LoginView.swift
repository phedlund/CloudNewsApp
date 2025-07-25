//
//  LoginView.swift
//  CloudNews
//
//  Created by Peter Hedlund on 7/25/25.
//

import SwiftUI
import WebKit

struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(SettingKeys.server) var server = ""
    @AppStorage(SettingKeys.productVersion) var productVersion = ""
    @KeychainStorage(SettingKeys.username) var username = ""
    @KeychainStorage(SettingKeys.password) var password = ""

    @State private var page = WebPage(navigationDecider: LoginNavigationDecider())

    private let serverPrefix = "/server:"
    private let userPrefix = "user:"
    private let passwordPrefix = "password:"

    var body: some View {
        WebView(page)
            .task {
                let characterSet = CharacterSet(charactersIn:"/").union(.whitespacesAndNewlines)
                var serverAddress = server.trimmingCharacters(in: characterSet)
                if !serverAddress.contains("://"),
                   !serverAddress.hasPrefix("http") {
                    serverAddress = "https://\(serverAddress)"
                }
                let urlString = "\(serverAddress)/index.php/login/flow"
                if let url = URL(string: urlString) {
                    var request = URLRequest(url: url)

                    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    let appName = "CloudNews"
                    let userAgent = "Mozilla/5.0 (iOS) \(appName)/\(appVersion ?? "")"
                    let language = Locale.preferredLanguages[0] as String

                    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                    request.addValue(language, forHTTPHeaderField: "Accept-Language")
                    request.addValue("true", forHTTPHeaderField: "OCS-APIREQUEST")
                    page.customUserAgent = userAgent
                    Task {
                        for try await event in page.load(request) {
                            // Optionally do something with `event`.
                            switch event {
                            case .committed:
                                print("Page committed, URL is now: \(String(describing: page.url))")
                            case .startedProvisionalNavigation:
                                print("Page started, URL is now: \(String(describing: page.url))")
                            case .finished:
                                print("Page finished, URL is now: \(String(describing: page.url))")

                            // Handling migrated from old WKWebView delegate method
                            case .receivedServerRedirect:
                                print("Redirect")

                                guard let url = page.url else { return }

                                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                                if components?.scheme == "nc", let path = components?.path {
                                    let pathItems = path.components(separatedBy: "&")
                                    print(pathItems)
                                    if let serverItem = pathItems.first(where: { $0.hasPrefix(serverPrefix) }),
                                       let userItem = pathItems.first(where: { $0.hasPrefix(userPrefix) }),
                                       let passwordItem = pathItems.first(where: { $0.hasPrefix(passwordPrefix) }) {
                                        server = String(serverItem.dropFirst(serverPrefix.count))
                                        username = String(userItem.dropFirst(userPrefix.count))
                                        password = String(passwordItem.dropFirst(passwordPrefix.count))
                                    } else {
                                        productVersion = ""
                                    }

                        #if !os(macOS)
                                    dismiss()
                        #else
                                    NotificationCenter.default.post(name: .loginComplete, object: nil)
                        #endif
                                }

                            @unknown default:
                                break
                            }
                        }
                    }

                }
            }
    }
}

#Preview {
    LoginView()
}
