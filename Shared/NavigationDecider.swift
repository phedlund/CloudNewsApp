//
//  NavigationDecider.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/21/25.
//

import WebKit

struct NavigationDecider: WebPage.NavigationDeciding {
    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
//        print(response.response.url?.absoluteString ?? "")
//        if response.response.url?.absoluteString.starts(with: "https://www.swift.org") == true {
//            .allow
//        } else {
//            .cancel
//        }
        return .allow
    }

    func decidePolicy(for action: WebPage.NavigationAction, preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        print(action.request.url?.absoluteString ?? "")
        print(action.request.url?.fragment() ?? "No Fragment")
        print(action.request.url?.query() ?? "No Query")

        if !(action.target?.isMainFrame ?? false) {
//            webView.load(action.request)
            print("I'm here")
            return .allow
        }



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
//        .allow
    }

//    func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
//        .useCredential(URLCredential(trust: challenge.protectionSpace.serverTrust ?? .self))
//    }
}
