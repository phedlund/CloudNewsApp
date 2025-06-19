//
//  ContentBlocker.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/6/22.
//

import Foundation
import WebKit

@MainActor
struct ContentBlocker {

    static func loadJson() -> String? {
        guard let url = Bundle.main.url(forResource: "block-ads", withExtension: "json"),
            let source = try? String(contentsOf: url, encoding: .utf8) else {
                assert(false)
                return nil
        }
        return source
    }

    static func ruleList() async throws -> WKContentRuleList? {
        guard let blockRules = ContentBlocker.loadJson() else {
            return nil
        }

        do {
            return try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: blockRules)
        } catch {
            return nil
        }
    }

}
