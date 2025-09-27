//
//  ContentBlocker.swift
//  CloudNews
//
//  Created by Peter Hedlund on 2/6/22.
//

import Foundation
import WebKit

class ContentBlocker {
    static let shared = ContentBlocker()
    private var cachedRuleList: WKContentRuleList?

    private static func loadJson() -> String? {
        guard let url = Bundle.main.url(forResource: "block-ads", withExtension: "json"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assert(false)
            return nil
        }
        return source
    }

    //    func ruleList() async -> WKContentRuleList? {
    //        if let cached = cacheQueue.sync(execute: { cachedRuleList }) {
    //            return cached
    //        }
    //        // Load the block rules synchronously, before any await
    //        guard let blockRules = loadJson() else {
    //            return nil
    //        }
    //        // Make a unique copy of the string to satisfy Sendable requirements
    //        let blockRulesCopy = String(blockRules)
    //        do {
    //            let compiled = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: blockRulesCopy)
    //            cacheQueue.async {
    //                self.cachedRuleList = compiled
    //            }
    //            return compiled
    //        } catch {
    //            return nil
    //        }
    //    }

    func rules(completion: @escaping @Sendable (WKContentRuleList?) -> Void) {
        if let cached = cachedRuleList {
            completion(cached)
            return
        }
        guard let blockRules = ContentBlocker.loadJson() else {
            completion(nil)
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: blockRules, completionHandler:  { @Sendable rules, error in
            Task { @MainActor in
                self.cachedRuleList = rules
            }
            completion(rules)
        })
    }
}

