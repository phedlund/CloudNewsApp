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
    public let item: CDItem
    public let size: CGSize

    private var feed: CDFeed?
    private var preferences = Preferences()

    init(item: CDItem, size: CGSize) {
        self.item = item
        self.feed = CDFeed.feed(id: item.feedId)
        self.size = size
        configure()
    }

    func configure() {
        if var html = item.body,
           let urlString = item.url,
           let url = URL(string: urlString) {
            let baseString = "\(url.scheme ?? "")://\(url.host ?? "")"
            if baseString.range(of: "youtu", options: .caseInsensitive) != nil {
                if html.range(of: "iframe", options: .caseInsensitive) != nil {
                    html = createYoutubeItem(html: html, urlString: urlString)
                } else if let urlString = item.url, urlString.contains("watch?v="), let equalIndex = urlString.firstIndex(of: "=") {
                    let videoIdStartIndex = urlString.index(after: equalIndex)
                    let videoId = String(urlString[videoIdStartIndex...])
                    let screenSize = UIScreen.main.nativeBounds.size
                    let margin = preferences.marginPortrait
                    let currentWidth = Double(screenSize.width / UIScreen.main.scale) * (Double(margin) / 100.0)
                    let newheight = currentWidth * 0.5625
                    let embed = "<embed id=\"yt\" src=\"http://www.youtube.com/embed/\(videoId)?playsinline=1\" type=\"text/html\" frameborder=\"0\" width=\"\(Int(currentWidth))px\" height=\"\(Int(newheight))px\"></embed>"
                    html = embed
                }
            }
            html = fixRelativeUrl(html: html, baseUrlString: baseString)
            saveItemSummary(html: html, item: item, feedTitle: feed?.title, size: size)
        }
    }

    func saveItemSummary(html: String, item: CDItem, feedTitle: String? = nil, size: CGSize = .zero) {
        var summary = replaceVideoIframe(html: html)
        var dateText = "";
        let dateNumber = TimeInterval(item.pubDate)
        let date = Date(timeIntervalSince1970: dateNumber)
        let dateFormat = DateFormatter()
        dateFormat.dateStyle = .medium;
        dateFormat.timeStyle = .short;
        dateText += dateFormat.string(from: date)
        let feedTitle = feedTitle ?? ""
        let title = item.displayTitle
        let url = item.url ?? ""
        var author = ""
        if let itemAuthor = item.author, !itemAuthor.isEmpty {
            author = "By \(itemAuthor)"
        }

        if let urlString = item.url,  let url = URL(string: urlString), let scheme = url.scheme, let host = url.host {
            let baseString = "\(scheme)://\(host)"
            if baseString.contains("youtu") {
                if summary.contains("iframe") {
                    summary = createYoutubeItem(html: summary, urlString: urlString)
                }
            }
            summary = fixRelativeUrl(html: summary, baseUrlString: baseString)
        }

        let htmlTemplate = """
        <?xml version="1.0" encoding="utf-8"?>
        <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <style>
                    \(self.updateCss(size: size))
                </style>
                <link rel="stylesheet" type="text/css" href="rss.css" />
                <title>
                    \(title)
                </title>
            </head>
            <body>
                <div class="header">
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
                        <a class="articleTitleLink" href="\(url)">\(title)</a>
                    </div>
                    <div class="articleAuthor">
                        <p>
                            \(author)
                        </p>
                    </div>
                    <div class="content">
                        <p>
                            \(summary)
                        </p>
                    </div>
                    <div class="footer">
                        <p>
                            <a class="footerLink" href="\(url)"><br />View Full Article</a>
                        </p>
                    </div>
                </div>
            </body>
        </html>
        """
        
        do {
            if let saveUrl = tempDirectory()?
                .appendingPathComponent("summary")
                .appendingPathExtension("html") {
                try htmlTemplate.write(to: saveUrl, atomically: true, encoding: .utf8)
            }
        } catch(let error) {
            print(error.localizedDescription)
        }
    }
    
    private func updateCss(size: CGSize) -> String {
        let currentWidth = Int((size.width) * CGFloat((Double(preferences.marginPortrait) / 100.0)))
        let currentWidthLandscape = (size.height) * CGFloat((Double(preferences.marginPortrait) / 100.0))

        return ":root {" +
        "--bg-color: \(Color.pbh.whiteBackground.hexaRGB!);" +
        "--text-color: \(Color.pbh.whiteText.hexaRGB!);" +
        "--font-size: \(preferences.fontSize)px;" +
        "--body-width-portrait: \(currentWidth)px;" +
        "--body-width-landscape: \(currentWidthLandscape)px;" +
        "--line-height: \(preferences.lineHeight)em;" +
        "--link-color: \(Color.pbh.whiteLink.hexaRGB!);" +
        "--footer-link: \(Color.pbh.whitePopoverBackground.hexaRGB!);" +
        "}"
    }

    func fixRelativeUrl(html: String, baseUrlString: String) -> String {
        guard let doc: Document = try? SwiftSoup.parse(html), let baseURL = URL(string: baseUrlString) else {
            return html
        }
        var result = html
        do {
            let srcs: Elements = try doc.select("img[src]")
            let srcsStringArray: [String?] = srcs.array().map { try? $0.attr("src").description }
            for src in srcsStringArray {
                if let src = src, let newSrc = URL(string: src, relativeTo: baseURL) {
                    let newSrcString = newSrc.absoluteString
                    result = result.replacingOccurrences(of: src, with: newSrcString)
                }
            }

            let hrefs: Elements = try doc.select("a[href]")
            let hrefsStringArray: [String?] = hrefs.array().map { try? $0.attr("href").description }
            for href in hrefsStringArray {
                if let href = href, let newHref = URL(string: href, relativeTo: baseURL) {
                    result = result.replacingOccurrences(of: href, with: newHref.absoluteString)
                }
            }
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("error")
        }
        return result
    }
    
    func replaceVideoIframe(html: String) -> String {
        guard let doc: Document = try? SwiftSoup.parse(html) else {
            return html
        }
        var result = html
        do {
            let iframes: Elements = try doc.select("iframe")
            for iframe in iframes {
                if let src = try iframe.getElementsByAttribute("src").first()?.attr("src") {
                    if src.contains("youtu"), let videoId = src.youtubeVideoID {
                        let screenSize = UIScreen.main.nativeBounds.size
                        let currentWidth = (screenSize.width / UIScreen.main.scale) * CGFloat(preferences.marginPortrait / 100);
                        let newheight = currentWidth * 0.5625;
                        let embed = String(format: "<embed id=\"yt\" src=\"http://www.youtube.com/embed/%@?playsinline=1\" type=\"text/html\" frameborder=\"0\" width=\"%ldpx\" height=\"%ldpdx\"></embed>", videoId, currentWidth, newheight)
                        result = result.replacingOccurrences(of: try iframe.html(), with: embed)
                    }
                    if src.contains("vimeo"), let videoId = src.vimeoID {
                        let screenSize = UIScreen.main.nativeBounds.size
                        let currentWidth = (screenSize.width / UIScreen.main.scale) * CGFloat(preferences.marginPortrait / 100);
                        let newheight = currentWidth * 0.5625;
                        let embed = String(format:"<iframe id=\"vimeo\" src=\"http://player.vimeo.com/video/%@\" type=\"text/html\" frameborder=\"0\" width=\"%ldpx\" height=\"%ldpdx\"></iframe>", videoId, currentWidth, newheight)
                        result = result.replacingOccurrences(of: try iframe.html(), with: embed)
                    }
                }
            }
        } catch { }

        return result
    }

    func createYoutubeItem(html: String, urlString: String) -> String {
        guard let doc: Document = try? SwiftSoup.parse(html) else {
            return html
        }
        var result = html
        do {
            let iframes: Elements = try doc.select("iframe")
            for iframe in iframes {
                if let videoId = urlString.youtubeVideoID {
                    let width = 700
                    let height = 700 * 0.5625
                    let embed = "<embed id=\"yt\" src=\"http://www.youtube.com/embed/\(videoId)?playsinline=1\" type=\"text/html\" frameborder=\"0\" width=\"\(width)px\" height=\"\(height)px\"></embed>"
                    result = try result.replacingOccurrences(of: iframe.outerHtml(), with: embed)
                }
            }
        } catch { }
        
        return result
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
        } catch { }
        return nil
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
        } catch { }
        return nil
    }
    
}
