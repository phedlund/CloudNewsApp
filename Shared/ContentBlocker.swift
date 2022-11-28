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

    private var rules: WKContentRuleList?

    func loadJson() -> String? {
        guard let path = Bundle.main.path(forResource: "block-ads", ofType: "json"),
            let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                assert(false)
                return nil
        }
        return source
    }

    func ruleList() async throws -> WKContentRuleList? {
        guard let blockRules = ContentBlocker.shared.loadJson() else {
            return nil
        }
        
        do {
            if rules == nil {
                rules = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: blockRules)
            }
            return rules
        } catch {
            return nil
        }
    }
    
}
