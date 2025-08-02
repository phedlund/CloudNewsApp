//
//  ArticleHelper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/25/18.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Observation
import SwiftSoup
import SwiftUI
import WebKit

class ArticleWebContent: Identifiable {
    @AppStorage(SettingKeys.fontSize) private var fontSize = Constants.ArticleSettings.defaultFontSize
    @AppStorage(SettingKeys.lineHeight) private var lineHeight = Constants.ArticleSettings.defaultLineHeight
    @AppStorage(SettingKeys.marginPortrait) private var marginPortrait = Constants.ArticleSettings.defaultMarginWidth

    var id: Int64 {
        item.id
    }
    var page: WebPage
    var item: Item

    private var isLoaded = false

    private var cssPath: String {
        if let bundleUrl = Bundle.main.url(forResource: "Web", withExtension: "bundle"),
           let bundle = Bundle(url: bundleUrl),
           let path = bundle.path(forResource: "rss", ofType: "css", inDirectory: "css") {
            return path
        } else {
            return ""
        }
    }

    init(item: Item) {
        self.item = item
        let webConfig = WebPage.Configuration()
        ContentBlocker.rules { rules in
            if let rules {
                Task { @MainActor in
                    webConfig.userContentController.add(rules)
                }
            }
        }
        page = WebPage(configuration: webConfig, navigationDecider: ArticleNavigationDecider())
    }

    func reloadItemSummary(_ fromSource: Bool = false) {
        if fromSource == true {
            isLoaded = false
        }
        if isLoaded {
            return
        }
        let title = item.displayTitle
        let summary = Self.output(item: item)
        let baseString = Self.baseString(item: item)
        let urlString = Self.itemUrl(item: item)
        let dateText = Self.dateText(item: item)
        let author = Self.itemAuthor(item: item)
        let feedTitle = item.feed?.title ?? "Untitled"
        let fileName = "summary_\(item.id)"

        let htmlTemplate = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
                <title>
                    \(title)
                </title>
            <style>\(updateCssVariables())</style>
            <link rel="stylesheet" href="\(cssPath)" media="all">
            <base href="\(baseString)">
            </head>
            <body>
                <article>
                    <div class="titleHeader">
                        <table width="100%" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                                <td>
                                    <div class="feedTitle">
                                        \(feedTitle)
                                    </div>
                                </td>
                                <td>
                                    <div class="articleDate">
                                        \(dateText)
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </div>
                    <div class="articleTitle">
                        <a class="articleTitleLink" href="\(urlString)">\(title)</a>
                    </div>
                    <div class="articleAuthor">
                        <p>
                            \(author)
                        </p>
                    </div>
                    <div class="articleBody">
                        <p>
                            \(summary)
                        </p>
                    </div>
                    <div class="footer">
                        <a href="\(urlString)"><br />\(urlString)</a>
                    </div>
                </article>
            </body>
        </html>
        """
        
        do {
            if let saveUrl = tempDirectory()?
                .appendingPathComponent(fileName)
                .appendingPathExtension("html") {
                try htmlTemplate.write(to: saveUrl, atomically: true, encoding: .utf8)
                if let feed = item.feed {
                    if feed.preferWeb == true,
                       let urlString = item.url,
                       let url = URL(string: urlString) {
                        page.load(URLRequest(url: url))
                    } else {
                        page.load(URLRequest(url: saveUrl))
                    }
                }
                isLoaded = true
            }
        } catch(let error) {
            print(error.localizedDescription)
        }
    }

    private static func baseString(item: Item) -> String {
        var result = ""

        if let urlString = item.url,
           let url = URL(string: urlString),
           let scheme = url.scheme,
           let host = url.host {
            result = "\(scheme)://\(host)"
        }
        return result
    }

    private static func output(item: Item) -> String {
        var result = ""

        if let html = item.body,
           let urlString = item.url,
           let url = URL(string: urlString),
           let scheme = url.scheme,
           let host = url.host {

            result = html
            do {
                let baseString = "\(scheme)://\(host)"
                let document = try SwiftSoup.parse(html, baseString)

                if baseString.lowercased().contains("youtu"), urlString.lowercased().contains("watch?v="), let equalIndex = urlString.firstIndex(of: "=") {
                    let videoIdStartIndex = urlString.index(after: equalIndex)
                    let videoId = String(urlString[videoIdStartIndex...])
                    try document.body()?.html(embedYTString(videoId))
                } else {
                    let iframes = try document.select("iframe")
                    for iframe in iframes {
                        let src = try iframe.attr("src")
                        if src.contains("youtu") || src.contains("vimeo") {
                            try iframe.wrap("<div class=\"video-wrapper\"></div>")
                        }
                    }
                }
                // Select all anchor tags with target="_blank"
                let links = try document.select("a[target=_blank]")
                // Iterate through the selected links and remove the "target" attribute
                for link in links {
                    try link.removeAttr("target") //
                }
                if let html = try document.body()?.html() {
                    result = html
                }
            } catch Exception.Error(_, let message) {
                print(message)
            } catch {
                print("error")
            }
        }
        return result
    }

    private static func embedYTString(_ videoId: String) -> String {
        return """
            <div class="video-wrapper">
                <iframe width="560" height="315" src="https://www.youtube.com/embed/\(videoId)" frameborder="0" allowfullscreen></iframe>
            </div>
            """
    }

    private static func itemUrl(item: Item) -> String {
        return item.url ?? ""
    }

    private static func itemAuthor(item: Item) -> String {
        var author = ""
        if let itemAuthor = item.author, !itemAuthor.isEmpty {
            author = "By \(itemAuthor)"
        }
        return author
    }

    private static func dateText(item: Item) -> String {
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .medium;
        dateFormat.timeStyle = .short;
        return dateFormat.string(from: item.pubDate)
    }

    private func updateCssVariables() -> String {
        let fontSize: Double = Double(fontSize) / 14.0
        return """
            :root {
                font: -apple-system-body;
                --bg-color: \(Color.phWhiteBackground.hexaRGB!);
                --text-color: \(Color.phWhiteText.hexaRGB!);
                --font-size: \(fontSize);
                --body-width-portrait: \(marginPortrait)vw;
                --body-width-landscape: \(marginPortrait)vw;
                --line-height: \(lineHeight)em;
                --link-color: \(Color.phWhiteLink.hexaRGB!);
            }
        """
    }

}

extension ArticleWebContent: Equatable {
    static func == (lhs: ArticleWebContent, rhs: ArticleWebContent) -> Bool {
        return lhs.item.id == rhs.item.id
    }
    

}

extension String {
    
    //based on https://gist.github.com/rais38/4683817
    /**
     @see https://devforums.apple.com/message/705665#705665
     extractYoutubeVideoID: works for the following URL formats:
     www.youtube.com/v/VIDEOID
     www.youtube.com?v=VIDEOID
     www.youtube.com/watch?v=WHsHKzYOV2E&feature=youtu.be
     www.youtube.com/watch?v=WHsHKzYOV2E
     youtu.be/KFPtWedl7wg_U923
     www.youtube.com/watch?feature=player_detailpage&v=WHsHKzYOV2E#t=31s
     youtube.googleapis.com/v/WHsHKzYOV2E
     www.youtube.com/embed/VIDEOID
     */
    var youtubeVideoID: String? {
        let pattern = "(?<=v(=|/))([-a-zA-Z0-9_]+)|(?<=youtu.be/)([-a-zA-Z0-9_]+)|(?<=embed/)([-a-zA-Z0-9_]+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let firstMatchingRange = regex.rangeOfFirstMatch(in: self, options: [], range: NSRange(location: 0, length: count))
            let startIndex = String.Index(utf16Offset: firstMatchingRange.lowerBound, in: self)
            let endIndex = String.Index(utf16Offset: firstMatchingRange.upperBound, in: self)
            return String(self[startIndex..<endIndex])
        } catch {
            return nil
        }
    }

    var vimeoID: String? {
        let pattern = "([0-9]{2,11})"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: count)
            guard let result = regex.firstMatch(in: self, range: range) else {
                return nil
            }
            return (self as NSString).substring(with: result.range)
        } catch {
            return nil
        }
    }
    
}
