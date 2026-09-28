//
//  Dog.swift
//  Protein
//
//  Created by Lakr Aream on 12/11/20.
//

import Foundation
import OSLog

internal let dogLogger = Logger(subsystem: "com.lakr233.dog", category: "Dog")

// MARK: - CHANGE ME IF NEEDED

// Dog_2021-03-01_22-10-43_ACAF51D1.log

internal let loggingPrefix = "Dog"
internal let loggingFormatter = "yyyy-MM-dd_HH-mm-ss"
internal let loggingRndSuffix = "AAAAAAAA"
internal let loggingSuffix = "log"
internal let cLogFilenameLenth = [
    loggingPrefix, "_",
    loggingFormatter, "_",
    loggingRndSuffix, ".",
    loggingSuffix,
]
.joined()
.count

// MARK: CHANGE ME IF NEEDED -

// MARK: - ERRORS

public enum DogError: Error {
    /// no directory was given and the documents directory is unavailable
    case noWritableDirectory
    /// the log directory could not be created
    case directoryUnavailable(URL)
    /// the log file could not be created or opened
    case fileUnavailable(URL)
}

// MARK: - THE CLASS

public final class Dog {
    public enum DogLevel: String {
        /// Everything
        case verbose
        /// Normal output like when the (information) was updated
        case info
        /// Recoverable issue (warning) that would not break the logic flow
        /// - if the user wrote the wrong data but we can ignore the error and continue to execute
        case warning
        /// Non-recoverable (error), will impact logic flow
        /// - such as permission denied and the method shall return or throw
        case error
        /// (Fatal) where the application must exit or terminate
        /// fatalError or assert failure
        case critical
    }

    /// how many logs that you want to keep
    /// set before calling initialization
    public var maximumLogCount = 128 {
        didSet { try? cleanLogs() }
    }

    /// the place we save our logs
    internal static let dirBase = "Journal"

    /// shared
    public static let shared = Dog()

    public internal(set) var currentLogFileLocation: URL?
    public internal(set) var currentLogFileDirLocation: URL?
    /// replaced under `executionLock` when initialization runs again
    internal var logFileHandler: FileHandle?

    /// Thread Safe
    internal let executionLock = NSLock()

    /// grouped tagging
    internal var lastTag: String?

    /// writes failed in a row, reported sparsely so a full disk does not flood
    internal var failedWriteCount = 0

    /// date formatter for log names and lines
    /// fixed to en_US_POSIX so the user's calendar, numbering system or
    /// 12-hour clock can not change a file name that is parsed back later
    internal let formatter: DateFormatter = {
        let initDateFormatter = DateFormatter()
        initDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        initDateFormatter.calendar = Calendar(identifier: .gregorian)
        initDateFormatter.dateFormat = loggingFormatter
        return initDateFormatter
    }()

    private init() {}
}
