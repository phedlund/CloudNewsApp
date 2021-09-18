//
//  Utilities.swift
//  Utilities
//
//  Created by Peter Hedlund on 9/6/21.
//

import Foundation

func tempDirectory() -> URL? {
    let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("CloudNews", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
    } catch {
        return nil
    }
    return tempDirURL
}
