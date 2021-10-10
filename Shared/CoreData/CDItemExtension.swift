//
//  CDItemExtension.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/9/21.
//

import CoreData
import SwiftSoup

extension CDItem {

    dynamic var displayTitle: String {
        guard let titleValue = title else {
            return "Untitled"
        }

        return plainSummary(raw: titleValue as String)
    }

    dynamic var displayBody: String {
        guard let summaryValue = body else {
            return "No Summary"
        }

        var summary: String = summaryValue as String
        if summary.range(of: "<style>", options: .caseInsensitive) != nil {
            if summary.range(of: "</style>", options: .caseInsensitive) != nil {
                if let start = summary.range(of:"<style>", options: .caseInsensitive)?.lowerBound,
                    let end = summary.range(of: "</style>", options: .caseInsensitive)?.upperBound {
                    let sub = summary[start..<end]
                    summary = summary.replacingOccurrences(of: sub, with: "")
                }
            }
        }
        return  plainSummary(raw: summary)
    }

    private func plainSummary(raw: String) -> String {
        guard let doc: Document = try? SwiftSoup.parse(raw) else {
            return raw
        } // parse html
        guard let txt = try? doc.text() else {
            return raw
        }
        return txt
    }

    
}
