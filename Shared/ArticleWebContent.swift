//
//  ArticleWebContent.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/25/18.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import SwiftSoup
import SwiftUI
import WebKit

// MARK: - Cache

/// Holds ArticleWebContent instances keyed by item ID, so WebViews are never
/// recreated unnecessarily and the WKWebView backing store stays alive.
@Observable @MainActor
final class ArticleWebContentCache {
//    static let shared = ArticleWebContentCache()

    private var cache: [Int64: ArticleWebContent] = [:]

//    private init() {}

    func content(for item: Item, openUrlAction: OpenURLAction) -> ArticleWebContent {
        if let existing = cache[item.id] {
            return existing
        }
        let newContent = ArticleWebContent(item: item, openUrlAction: openUrlAction)
        cache[item.id] = newContent
        return newContent
    }

    /// Call when an item's body changes (e.g. after a sync) so the next
    /// access rebuilds from fresh HTML.
    func invalidate(itemID: Int64) {
        cache.removeValue(forKey: itemID)
    }

    /// Evict entries whose IDs are not in the supplied set (e.g. after feed
    /// refresh removes old items).
    func evict(keepingIDs ids: Set<Int64>) {
        cache = cache.filter { ids.contains($0.key) }
    }

    /// Drop everything — useful on logout / account switch.
    func removeAll() {
        cache.removeAll()
    }
}

// MARK: - ArticleWebContent

final class ArticleWebContent: Identifiable {
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var id: Int64 { item.id }
    let page: WebPage
    let item: Item

    /// Tracks whether the current item summary has been loaded into `page`.
    /// Stored as a plain Bool because ArticleWebContent is now a class —
    /// mutations are visible to all holders of this reference.
    private var isLoaded = false

    init(item: Item, openUrlAction: OpenURLAction) {
        self.item = item
        let webConfig = WebPage.Configuration()
        ContentBlocker.shared.rules { rules in
            if let rules {
                Task { @MainActor in
                    webConfig.userContentController.add(rules)
                }
            }
        }
        page = WebPage(
            configuration: webConfig,
            navigationDecider: ArticleNavigationDecider(openUrlAction: openUrlAction)
        )
    }

    func reloadItemSummary(_ fromSource: Bool = false) {
        if fromSource {
            isLoaded = false
        }
        guard !isLoaded else { return }

        guard let feed = item.feed else { return }

        if feed.preferWeb == true,
           let urlString = item.url,
           let url = URL(string: urlString) {
            page.load(URLRequest(url: url))
            isLoaded = true
            return
        }

        do {
            let htmlTemplate = buildHTMLTemplate()
            let fileName = "summary_\(item.id)"
            if let saveUrl = tempDirectory()?
                .appendingPathComponent(fileName)
                .appendingPathExtension("html") {
                try htmlTemplate.write(to: saveUrl, atomically: true, encoding: .utf8)
                page.load(URLRequest(url: saveUrl))
                isLoaded = true
            }
        } catch {
            print(error.localizedDescription)
        }
    }

    // MARK: - Private helpers

    private func buildHTMLTemplate() -> String {
        let title     = item.displayTitle
        let base      = baseString()
        let summary   = output()
        let urlString = item.url ?? ""
        let dateText  = DateFormatter.dateTextFormatter.string(from: item.pubDate)
        let author    = itemAuthor()
        let feedTitle = item.feed?.title ?? "Untitled"

        return """
        <!DOCTYPE html>
        <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
                <title>\(title)</title>
                <style>
                    \(updateCssVariables())
                    \(CssProvider.shared.css())
                </style>
                <base href="\(base)">
            </head>
            <body>
                <article>
                    <div class="titleHeader">
                        <table width="100%" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                                <td><div class="feedTitle">\(feedTitle)</div></td>
                                <td><div class="articleDate">\(dateText)</div></td>
                            </tr>
                        </table>
                    </div>
                    <div class="articleTitle">
                        <a class="articleTitleLink" href="\(urlString)">\(title)</a>
                    </div>
                    <div class="articleAuthor"><p>\(author)</p></div>
                    <div class="articleBody"><p>\(summary)</p></div>
                    <div class="footer">
                        <a href="\(urlString)"><br />\(urlString)</a>
                    </div>
                </article>
            </body>
        </html>
        """
    }

    private func baseString() -> String {
        guard
            let urlString = item.url,
            let url = URL(string: urlString),
            let scheme = url.scheme,
            let host = url.host
        else { return "" }
        return "\(scheme)://\(host)"
    }

    private func output() -> String {
        guard let html = item.body, let urlString = item.url else { return "" }

        do {
            let base = baseString()
            let document = try SwiftSoup.parse(html, base)

            if let components = URLComponents(string: urlString.lowercased()),
               let host = components.host {
                if host.contains("youtu") {
                    if let videoID = queryVideoID(from: components) {
                        try document.body()?.html(embedYTString(videoID))
                    } else if components.path.contains("shorts"),
                              let url = URL(string: urlString.lowercased()) {
                        try document.body()?.html(embedYTString(url.lastPathComponent))
                    }
                } else {
                    for iframe in try document.select("iframe") {
                        let src = try iframe.attr("src")
                        if src.contains("youtu") || src.contains("vimeo") {
                            try iframe.wrap("<div class=\"video-wrapper\"></div>")
                        }
                    }
                }
            }

            // Strip target="_blank" so links open in-app rather than escaping to Safari.
            for link in try document.select("a[target=_blank]") {
                try link.removeAttr("target")
            }

            return try document.body()?.html() ?? html
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("SwiftSoup error: \(error)")
        }
        return html
    }

    /// Extracts the `v=` query parameter from a YouTube URL's query items.
    private func queryVideoID(from components: URLComponents) -> String? {
        components.queryItems?.first(where: { $0.name == "v" })?.value
    }

    private func embedYTString(_ videoId: String) -> String {
        """
        <div class="video-wrapper">
            <iframe width="560" height="315"
                src="https://www.youtube.com/embed/\(videoId)"
                frameborder="0" allowfullscreen></iframe>
        </div>
        """
    }

    private func itemAuthor() -> String {
        guard let author = item.author, !author.isEmpty else { return "" }
        return String(format: NSLocalizedString("By %@", comment: "By #author#"), author)
    }

    private func updateCssVariables() -> String {
        let scaledFont = Double(fontSize) / 14.0
        return """
        :root {
            font: -apple-system-body;
            --bg-color: \(Color.phWhiteBackground.hexaRGB!);
            --text-color: \(Color.phWhiteText.hexaRGB!);
            --font-size: \(scaledFont);
            --body-width-portrait: \(marginPortrait)vw;
            --body-width-landscape: \(marginPortrait)vw;
            --line-height: \(lineHeight)em;
            --link-color: \(Color.phWhiteLink.hexaRGB!);
        }
        """
    }
}

// MARK: - Equatable

extension ArticleWebContent: Equatable {
    static func == (lhs: ArticleWebContent, rhs: ArticleWebContent) -> Bool {
        lhs.item.id == rhs.item.id
    }
}

// MARK: - YouTube / Vimeo ID extraction

extension String {
    // Based on https://gist.github.com/rais38/4683817
    /// Extracts a YouTube video ID from the many URL shapes YouTube uses.
    var youtubeVideoID: String? {
        let pattern = "(?<=v(=|/))([-a-zA-Z0-9_]+)|(?<=youtu\\.be/)([-a-zA-Z0-9_]+)|(?<=embed/)([-a-zA-Z0-9_]+)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
            let range = Range(match.range, in: self)
        else { return nil }
        return String(self[range])
    }

    var vimeoID: String? {
        let pattern = "([0-9]{2,11})"
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
            let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
            let range = Range(match.range, in: self)
        else { return nil }
        return String(self[range])
    }
}

