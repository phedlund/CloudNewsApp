//
//  LoginWebView.swift
//  LoginWebView
//
//  Created by Peter Hedlund on 8/9/21.
//

import SwiftUI
import WebKit

struct LoginWebViewView: View {
    @StateObject var webViewManager = WebViewManager()
    @AppStorage(SettingKeys.server) var server = ""

    var body: some View {
        VStack {
        LoginWebView(webView: webViewManager.webView)
            .onAppear {
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
                    webViewManager.webView.customUserAgent = userAgent
                    webViewManager.webView.load(request)
                }
            }
        }
    }
}

struct LoginWebView_Previews: PreviewProvider {
    static var previews: some View {
        LoginWebViewView(server: "")
    }
}

#if os(macOS)
struct LoginWebView: NSViewRepresentable {
    @Environment(\.dismiss) var dismiss

    @AppStorage(SettingKeys.server) var server: String = ""
    @AppStorage(SettingKeys.productVersion) var productVersion = ""
    @KeychainStorage(SettingKeys.username) var username: String = ""
    @KeychainStorage(SettingKeys.password) var password: String = ""

    public let webView: WKWebView

    public init(webView: WKWebView) {
      self.webView = webView
    }

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ uiView: WKWebView, context: Context) {
    }

    func makeCoordinator() -> LoginWebViewCoordinator {
        LoginWebViewCoordinator(self)
    }
    
}
#else
struct LoginWebView: UIViewRepresentable {
    @Environment(\.dismiss) var dismiss

    @AppStorage(SettingKeys.server) var server: String = ""
    @AppStorage(SettingKeys.productVersion) var productVersion = ""
    @KeychainStorage(SettingKeys.username) var username: String = ""
    @KeychainStorage(SettingKeys.password) var password: String = ""

    public let webView: WKWebView

    public init(webView: WKWebView) {
      self.webView = webView
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }

    func makeCoordinator() -> LoginWebViewCoordinator {
        LoginWebViewCoordinator(self)
    }

}
#endif

class LoginWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let serverPrefix = "/server:"
    private let userPrefix = "user:"
    private let passwordPrefix = "password:"

    var parent: LoginWebView

    init(_ parent: LoginWebView) {
        self.parent = parent
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {

        guard let url = webView.url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.scheme == "nc", let path = components?.path {
            let pathItems = path.components(separatedBy: "&")
            print(pathItems)
            if let serverItem = pathItems.first(where: { $0.hasPrefix(serverPrefix) }),
               let userItem = pathItems.first(where: { $0.hasPrefix(userPrefix) }),
               let passwordItem = pathItems.first(where: { $0.hasPrefix(passwordPrefix) }) {
                parent.server = String(serverItem.dropFirst(serverPrefix.count))
                parent.username = String(userItem.dropFirst(userPrefix.count))
                parent.password = String(passwordItem.dropFirst(passwordPrefix.count))
            } else {
                parent.productVersion = ""
            }

#if !os(macOS)
            parent.dismiss()
#else
            NotificationCenter.default.post(name: .loginComplete, object: nil)
#endif
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("didCommit")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if let urlError = error as? URLError {
            webView.loadHTMLString(urlError.localizedDescription, baseURL: urlError.failingURL)
        } else {
            webView.loadHTMLString(error.localizedDescription, baseURL: URL(string: "data:text/html"))
        }
    }

    func webView(_ webView: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            return (URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            return (URLSession.AuthChallengeDisposition.useCredential, nil)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
    }

}
