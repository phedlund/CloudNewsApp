//
//  LogManager.swift
//  CloudNews
//
//  Created by Peter Hedlund on 10/27/25.
//

import Foundation
import Puppy

class LogManager {
    static let shared = LogManager()
    let logger: Puppy
    let fileURL: URL

    private init() {
        fileURL = URL.documentsDirectory.appendingPathComponent("cloudnews_logs.log")

        let rotationConfig = RotationConfig(suffixExtension: .date_uuid,
                                            maxFileSize: 2 * 1024 * 1024,
                                            maxArchivedFilesCount: 3)

        let fileRotation = try! FileRotationLogger("dev.pbh.cloudnews.filerotation",
                                                   logFormat: LogFormatter(),
                                                    fileURL: fileURL,
                                                    rotationConfig: rotationConfig,
                                                    delegate: nil)

        #if DEBUG
        let console = ConsoleLogger("dev.pbh.cloudnews.console")
        logger = Puppy(loggers: [fileRotation, console])
        #else
        logger = Puppy(loggers: [fileRotation])
        #endif
    }

}

struct LogFormatter: LogFormattable {
    private let dateFormat = DateFormatter()

    init() {
        dateFormat.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(secondsFromGMT: 0) // UTC
    }

    func formatMessage(_ level: LogLevel, message: String, tag: String, function: String,
                       file: String, line: UInt, swiftLogInfo: [String : String],
                       label: String, date: Date, threadID: UInt64) -> String {
        let date = dateFormatter(date, withFormatter: dateFormat)
        return "\(date), \(level), \(message)"
    }
}
