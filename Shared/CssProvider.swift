//
//  CssProvider.swift
//  CloudNews
//
//  Created by Peter Hedlund on 8/3/25.
//

import Foundation

class CssProvider {
    static let shared = CssProvider()
    private var cachedCss: String?

    static var cssPath: String {
        if let bundleUrl = Bundle.main.url(forResource: "Web", withExtension: "bundle"),
           let bundle = Bundle(url: bundleUrl),
           let path = bundle.path(forResource: "rss", ofType: "css", inDirectory: "css") {
            return path
        } else {
            return ""
        }
    }

    func css() -> String {
        if let cachedCss = cachedCss {
            return cachedCss
        }
        
        do {
            let css = try String(contentsOfFile: CssProvider.cssPath, encoding: .utf8)
            cachedCss = css
            return css
        } catch {
            return ""
        }
    }

}
