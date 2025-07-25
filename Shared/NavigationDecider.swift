//
//  NavigationDecider.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/21/25.
//

import WebKit

struct ArticleNavigationDecider: WebPage.NavigationDeciding {
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

//    func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
//        .useCredential(URLCredential(trust: challenge.protectionSpace.serverTrust ?? .self))
//    }
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
