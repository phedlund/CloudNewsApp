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
    static let emptyNodeGuid = "0044f316-8559-4aea-b5fe-41084135730b"
    static let allNodeGuid = "72137d96-4ef2-11ec-81d3-0242ac130003"
    static let starNodeGuid = "967917a4-4ef2-11ec-81d3-0242ac130003"

    static let email = "support@pbh.dev"
    static let website = "https://pbh.dev/cloudnews"
    static let subject = NSLocalizedString("CloudNews Support Request", comment: "Support email subject")
    static let message = NSLocalizedString("<Please state your question or problem here>", comment: "Support email body placeholder")

    struct ArticleSettings {
    #if os(macOS)
        static let minFontSize = 11
    #else
        static let minFontSize = UIDevice.current.userInterfaceIdiom == .pad ? 11 : 9
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
