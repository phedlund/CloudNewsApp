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
    @Environment(\.dismissWindow) var dismissWindow
    @AppStorage(SettingKeys.server) var server = ""

    @State private var loginSchemeHandler: LoginSchemeHandler
    @State private var page: WebPage

    init() {
        let handler = LoginSchemeHandler()
        var config = WebPage.Configuration()
        if let scheme = URLScheme("nc") {
            config.urlSchemeHandlers = [scheme: handler]
        }
        let page = WebPage(configuration: config,
                           navigationDecider: LoginNavigationDecider())
        self._loginSchemeHandler = State(initialValue: handler)
        self._page = State(initialValue: page)
    }

    var body: some View {
        WebView(page)
            .onChange(of: loginSchemeHandler.loginComplete) { _, newValue in
                if newValue == true {
#if !os(macOS)
                    dismiss()
#else
                    NotificationCenter.default.post(name: .loginComplete, object: nil)
                    dismissWindow(id: "login")
#endif
                }
            }
            .task {
                startLoginFlow()
            }
    }

    private func startLoginFlow() {
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
                    case .receivedServerRedirect:
                        print("Redirect")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
