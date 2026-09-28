//
//  File.swift
//
//
//  Created by Lakr Aream on 2021/8/7.
//

import Foundation

internal extension Dog {
    /// Compare date with log file name
    /// - Parameters:
    ///   - a: log a
    ///   - b: log b
    /// - Returns: if a was earlier
    func sortCompareFileName(a: String, b: String) -> Bool {
        // bad file name
        if a.count != cLogFilenameLenth || b.count != cLogFilenameLenth {
            return a < b
        }
        // eg. "Dog_"
        let prefixLenth = [
            loggingPrefix, "_",
        ]
        .joined()
        .count
        // eg. "_ACAF51D1.log"
        let suffixLenth = [
            "_",
            loggingRndSuffix, ".",
            loggingSuffix,
        ]
        .joined()
        .count
        // trim to grab data
        let dateStrA = String(a.dropFirst(prefixLenth).dropLast(suffixLenth))
        let dateStrB = String(b.dropFirst(prefixLenth).dropLast(suffixLenth))
        let dateA = formatter.date(from: dateStrA)
        let dateB = formatter.date(from: dateStrB)
        if let dateA = dateA, let dateB = dateB {
            // a is early then b
            return dateA.timeIntervalSince(dateB) < 0
        } else {
            // can not process
            dogLogger.warning("unparsable log file name, comparing as text: \(a, privacy: .public) \(b, privacy: .public)")
            return a < b
        }
    }

    /// Clean logs that exceed the limit by maximumLogCount
    /// - Throws: if any error
    func cleanLogs() throws {
        guard let underDir = currentLogFileDirLocation else {
            dogLogger.warning("unable to find working location")
            return
        }
        // grab our own log files, anything else in the folder is not ours to delete
        let logFiles = try FileManager
            .default
            .contentsOfDirectory(atPath: underDir.path)
            .filter { $0.hasPrefix(loggingPrefix + "_") && $0.hasSuffix("." + loggingSuffix) }
        let deleteCount = logFiles.count - maximumLogCount
        guard deleteCount > 0 else {
            dogLogger.debug("\(logFiles.count, privacy: .public) log file(s) kept, limit \(self.maximumLogCount, privacy: .public)")
            return
        }
        dogLogger.info("removing \(deleteCount, privacy: .public) of \(logFiles.count, privacy: .public) log file(s), limit \(self.maximumLogCount, privacy: .public)")
        // oldest first, by the date in the name
        let oldest = logFiles
            .sorted { a, b -> Bool in sortCompareFileName(a: a, b: b) }
            .prefix(deleteCount)
        for name in oldest {
            let file = underDir.appendingPathComponent(name)
            do {
                try FileManager.default.removeItem(at: file)
                dogLogger.debug("removed old log: \(file.path, privacy: .public)")
            } catch {
                // keep going, one stuck file must not keep the rest forever
                dogLogger.error("failed to remove old log at \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
