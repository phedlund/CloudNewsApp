//
//  AppGroup.swift
//  CloudNews
//
//  Created by Peter Hedlund on 5/5/25.
//

import Foundation
import WidgetKit

struct SnapshotData: Codable, Hashable {
    var title: String
    var feed: String
    var pubDate: Date
    var thumbnailUrl: URL?
}

struct Snapshot {
    static let identifier = "group.dev.pbh.cloudnews"
    static let snapshotFile = "snapshot.json"

    static func readSnapshot() throws -> [SnapshotData] {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        if let fileUrl = containerURL?.appendingPathComponent(snapshotFile),
        FileManager.default.fileExists(atPath: fileUrl.path) {
            let decodedSnapshot = try JSONDecoder().decode([SnapshotData].self, from: Data(contentsOf: fileUrl))
            return decodedSnapshot
        } else {
            return [SnapshotData]()
        }
    }

    static func writeSnapshot(with data: [SnapshotData]) throws {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        if let fileUrl = containerURL?.appendingPathComponent(snapshotFile) {
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                try FileManager.default.removeItem(at: fileUrl)
            }
            let data = try JSONEncoder().encode(data)
            try data.write(to: fileUrl)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

}
