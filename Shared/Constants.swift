//
//  Constants.swift
//  CloudNews
//
//  Created by Peter Hedlund on 3/19/23.
//

import Foundation
#if !os(macOS)
import UIKit
#endif

struct Constants {
    static let appRefreshTaskId = "dev.pbh.cloudnews.sync"
    static let appUrlSessionId = "dev.pbh.cloudnews.background"
    static let appGroup = "group.dev.pbh.cloudnews"

    static let emptyNodeGuid = "0044f316-8559-4aea-b5fe-41084135730b"
    static let allNodeGuid = "aaaa"
    static let unreadNodeGuid = "bbbb"
    static let starNodeGuid = "cccc"

    static let email = "support@pbh.dev"
    static let website = "https://pbh.dev/cloud-news"
    static let subject = NSLocalizedString("CloudNews Support Request", comment: "Support email subject")
    static let message = NSLocalizedString("<Please state your question or problem here>", comment: "Support email body placeholder")

    static let allArticles = NSLocalizedString("All Articles", comment: "Title for all articles")
    static let unreadArticles = NSLocalizedString("Unread Articles", comment: "Title for unread articles")
    static let starredArticles = NSLocalizedString("Starred Articles", comment: "Title for starred articles")
    static let genericUntitled = NSLocalizedString("Untitled", comment: "Generic untitled")
    static let untitledFeedName = NSLocalizedString("Untitled Feed", comment: "Untitled feed name")
    static let untitledFolderName = NSLocalizedString("Untitled Folder", comment: "Untitled folder name")
    static let noError = NSLocalizedString("No error", comment: "No error")

    struct SyncMessages {
        static let gettingStarted = NSLocalizedString("Getting started…", comment: "")
        static let updatingFolders = NSLocalizedString("Updating folders…", comment: "")
        static let updatingFeeds = NSLocalizedString("Updating feeds…", comment: "")
        static let updatingArticles = NSLocalizedString("Updating articles…", comment: "")
        static let updatingCount = NSLocalizedString("Updating %d of %d…", comment: "")
        static let updatingUnreadArticles = NSLocalizedString("Updating unread articles…", comment: "")
        static let updatingStarredArticles = NSLocalizedString("Updating starred articles…", comment: "")
        static let updatingFavicons = NSLocalizedString("Updating favicons…", comment: "")
    }

    struct Headers {
        static let contentTypeJson = "application/json"
        static let authorization = "Authorization"
        static let accept = "Accept"
        static let contentType = "Content-Type"
    }

    struct ArticleSettings {
    #if os(macOS)
        static let minFontSize = 11
    #else
        static let minFontSize = 10
    #endif
        static let defaultFontSize = 14
        static let maxFontSize = 30
        static let minLineHeight = 1.2
        static let defaultLineHeight = 1.4
        static let maxLineHeight = 2.6
        static let minMarginWidth = 45 //%
        static let defaultMarginWidth = 70 //%
        static let maxMarginWidth = 95 //%
    }

}
