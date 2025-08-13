//
//  NavigationDecider.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/21/25.
//

import WebKit
import SwiftUI

struct ArticleNavigationDecider: WebPage.NavigationDeciding {
//    let openUrlAction: OpenURLAction

    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        return .allow
    }

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        if let scheme = action.request.url?.scheme {
            if scheme == "file" || scheme.hasPrefix("itms") {
                if let url = action.request.url {
                    if url.absoluteString.contains("itunes.apple.com") || url.absoluteString.contains("apps.apple.com") {
//                        openUrlAction.callAsFunction(url)
                        return .cancel
                    }
                }
            }
        }
        return .allow
    }

}

struct LoginNavigationDecider: WebPage.NavigationDeciding {

    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        return .allow
    }

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        return .allow
    }

    func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            return (URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            return (URLSession.AuthChallengeDisposition.useCredential, nil)
        }
    }
}

@Observable
class LoginSchemeHandler: URLSchemeHandler {
    typealias TaskSequence = AsyncThrowingStream<URLSchemeTaskResult, Error>

    @ObservationIgnored @AppStorage(SettingKeys.server) var server = ""
    @ObservationIgnored @AppStorage(SettingKeys.productVersion) var productVersion = ""
    @ObservationIgnored @KeychainStorage(SettingKeys.username) var username = ""
    @ObservationIgnored @KeychainStorage(SettingKeys.password) var password = ""

    var loginComplete = false

    private let serverPrefix = "server:"
    private let userPrefix = "user:"
    private let passwordPrefix = "password:"

    func reply(for request: URLRequest) -> AsyncThrowingStream<URLSchemeTaskResult, Error> {
        AsyncThrowingStream { continuation in
            defer { continuation.finish() }

            guard let url = request.url else {
                continuation.finish(throwing: URLError(.badURL))
                return
            }

            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !path.isEmpty else {
                return
            }

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

            // Send a URLResponse first
            let response = URLResponse(
                url: url,
                mimeType: "text/html",
                expectedContentLength: -1,
                textEncodingName: "utf-8"
            )
            continuation.yield(.response(response))
            loginComplete = true
        }
    }

}
