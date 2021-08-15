//
//  LoginWebView.swift
//  LoginWebView
//
//  Created by Peter Hedlund on 8/9/21.
//

import SwiftUI
import WebKit

struct LoginWebViewView: View {
    @StateObject var webViewManager = WebViewManager(type: .login)
    var server: String

    var body: some View {
        VStack {
        LoginWebView(webView: webViewManager.webView)
            .onAppear {
                var serverAddress = server.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                if !serverAddress.contains("://"),
                   !serverAddress.hasPrefix("http") {
                    serverAddress = "https://\(serverAddress)"
                }
                let urlString = "\(serverAddress)/index.php/login/flow"
                if let url = URL(string: urlString) {
                    var request = URLRequest(url: url)

                    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    let appName = "CloudNews" // Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
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
    public let webView: WKWebView

    public init(webView: WKWebView) {
      self.webView = webView
    }

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ uiView: WKWebView, context: Context) {
    }

}
#else
struct LoginWebView: UIViewRepresentable {
    @Environment(\.dismiss) var dismiss

    @AppStorage(StorageKeys.server) var server: String = ""
    @AppStorage(StorageKeys.isLoggedIn) var isLoggedIn: Bool = false
    @KeychainStorage(StorageKeys.username) var username: String = ""
    @KeychainStorage(StorageKeys.password) var password: String = ""

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
    var parent: LoginWebView

    init(_ parent: LoginWebView) {
        self.parent = parent
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {

        guard let url = webView.url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        print(components?.scheme ?? "")
        print(components?.path ?? "")
        print(components?.fragment ?? "")
        print(components?.user ?? "")
        if components?.scheme == "nc", let path = components?.path {
            let pathItems = path.components(separatedBy: "&")
            print(pathItems)
            if let serverItem = pathItems.first(where: { $0.hasPrefix("/server:") }) {
                parent.server = String(serverItem.dropFirst(8))
            }
            if let userItem = pathItems.first(where: { $0.hasPrefix("user:") }) {
                parent.username = String(userItem.dropFirst(5))
            }
            if let passwordItem = pathItems.first(where: { $0.hasPrefix("password:") }) {
                parent.password = String(passwordItem.dropFirst(9))
            }
            if !parent.server.isEmpty, !parent.username.isEmpty, !parent.password.isEmpty {
                parent.isLoggedIn = true
            }
            parent.dismiss()
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {

    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
//        parent.server = ""
//        parent.username = ""
//        parent.password = ""
//        parent.isLoggedIn = false

//        var errorMessage = error.localizedDescription
//
//        for (key, value) in (error as NSError).userInfo {
//            let message = "\(key) \(value)\n"
//            errorMessage = errorMessage + message
//        }
//
//        let alertController = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: errorMessage, preferredStyle: .alert)
//
//        alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { action in }))
//
//        self.present(alertController, animated: true)
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        decisionHandler(.allow)

        /* TEST NOT GOOD DON'T WORKS

         if let data = navigationAction.request.httpBody {
             let str = String(decoding: data, as: UTF8.self)
             print(str)
         }

         guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if String(describing: url).hasPrefix(NCBrandOptions.shared.webLoginAutenticationProtocol) {
            decisionHandler(.allow)
            return
        } else if navigationAction.request.httpMethod != "GET" || navigationAction.request.value(forHTTPHeaderField: "OCS-APIRequest") != nil {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.cancel)

        let language = NSLocale.preferredLanguages[0] as String
        var request = URLRequest(url: url)

        request.setValue(CCUtility.getUserAgent(), forHTTPHeaderField: "User-Agent")
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
        */
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation");
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        activityIndicator.stopAnimating()
//        print("didFinishProvisionalNavigation");
//
//        if loginFlowV2Available {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                NCCommunication.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { (server, loginName, appPassword, errorCode, errorDescription) in
//                    if errorCode == 0 && server != nil && loginName != nil && appPassword != nil {
//                        self.createAccount(server: server!, username: loginName!, password: appPassword!)
//                    }
//                }
//            }
//        }
    }


}
