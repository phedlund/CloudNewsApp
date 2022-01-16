//
//  Utilities.swift
//  Utilities
//
//  Created by Peter Hedlund on 9/6/21.
//

import UIKit

extension TimeInterval {
    static let fiveMinutes: TimeInterval = 300
}

extension URL {

    init?(withCheck string: String?) {
        let regEx = "((https|http)://)((\\w|-)+)(([.]|[/])((\\w|-)+))+"
        guard
            let urlString = string,
            let url = URL(string: urlString),
            NSPredicate(format: "SELF MATCHES %@", argumentArray: [regEx]).evaluate(with: urlString),
            UIApplication.shared.canOpenURL(url)
        else {
            return nil
        }
        self = url
    }
    
}

func tempDirectory() -> URL? {
    let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("CloudNews", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        return nil
    }
    return tempDirURL
}
