//
//  ArticleHelper.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/25/18.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Combine
import SwiftSoup
import SwiftUI

class ArticleWebContent: ObservableObject {
    @Published public var url: URL?
    private let author: String
    private let title: String
    private let feedTitle: String
    private let dateText: String
    private let baseString: String
    private let urlString: String
    private let summary: String
    let fileName: String
    private var preferences = Preferences()
    private var cancellables = Set<AnyCancellable>()
    private var isInInit = false

    private var cssPath: String {
        if let bundleUrl = Bundle.main.url(forResource: "Web", withExtension: "bundle"),
           let bundle = Bundle(url: bundleUrl),
           let path = bundle.path(forResource: "rss", ofType: "css", inDirectory: "css") {
            return path
        } else {
            return ""
        }
    }

    init(item: CDItem?) {
        isInInit = true
        if let item = item {
            let feed = CDFeed.feed(id: item.feedId)
            title = item.displayTitle
            summary = Self.output(item: item)
            baseString = Self.baseString(item: item)
            urlString = Self.itemUrl(item: item)
            dateText = Self.dateText(item: item)
            author = Self.itemAuthor(item: item)
            feedTitle = feed?.title ?? "Untitled"
            fileName = "summary_\(item.id)"
        } else {
            title = "Untitled"
            summary = "No Summary"
            baseString = ""
            urlString = ""
            dateText = ""
            author = ""
            feedTitle = "Untitled"
            fileName = "summary_000"
        }

        preferences.$marginPortrait.sink { [weak self] _ in
            guard let self, !self.isInInit else { return }
            self.saveItemSummary()
        }
        .store(in: &cancellables)

        preferences.$fontSize.sink { [weak self] _ in
            guard let self, !self.isInInit else { return }
            self.saveItemSummary()
        }
        .store(in: &cancellables)

        preferences.$lineHeight.sink { [weak self] _ in
            guard let self, !self.isInInit else { return }
            self.saveItemSummary()
        }
        .store(in: &cancellables)

        saveItemSummary()
        isInInit = false
    }

    private func saveItemSummary() {

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
                url = saveUrl
                objectWillChange.send()
            }
        } catch(let error) {
            print(error.localizedDescription)
        }
    }

    private static func baseString(item: CDItem) -> String {
        var result = ""

        if let urlString = item.url,
           let url = URL(string: urlString),
           let scheme = url.scheme,
           let host = url.host {
            result = "\(scheme)://\(host)"
        }
        return result
    }

    private static func output(item: CDItem) -> String {
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

    private static func itemUrl(item: CDItem) -> String {
        return item.url ?? ""
    }

    private static func itemAuthor(item: CDItem) -> String {
        var author = ""
        if let itemAuthor = item.author, !itemAuthor.isEmpty {
            author = "By \(itemAuthor)"
        }
        return author
    }

    private static func dateText(item: CDItem) -> String {
        let dateNumber = TimeInterval(item.pubDate)
        let date = Date(timeIntervalSince1970: dateNumber)
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .medium;
        dateFormat.timeStyle = .short;
        return dateFormat.string(from: date)
    }

    private func updateCssVariables() -> String {
        let fontSize: Double = Double(preferences.fontSize) / 14.0
        return """
            :root {
                font: -apple-system-body;
                --bg-color: \(Color.pbh.whiteBackground.hexaRGB!);
                --text-color: \(Color.pbh.whiteText.hexaRGB!);
                --font-size: \(fontSize);
                --body-width-portrait: \(preferences.marginPortrait)vw;
                --body-width-landscape: \(preferences.marginPortrait)vw;
                --line-height: \(preferences.lineHeight)em;
                --link-color: \(Color.pbh.whiteLink.hexaRGB!);
            }
        """
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
