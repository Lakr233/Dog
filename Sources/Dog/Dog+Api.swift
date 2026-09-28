//
//  Dog.swift
//  Protein
//
//  Created by Lakr Aream on 12/15/20.
//

import Foundation

public extension Dog {
    /// grab all available logs
    /// - Returns: there file url
    func obtainAllLogFilePath() -> [URL] {
        var ret = [URL]()
        if let base = currentLogFileDirLocation,
           let items = try? FileManager.default.contentsOfDirectory(atPath: base.path) {
            for item in items where item.hasPrefix(loggingPrefix) {
                ret.append(base.appendingPathComponent(item))
            }
        }
        return ret
    }

    /// grab current logs
    /// - Returns: log in String
    func obtainCurrentLogContent() -> String {
        var str = ""
        if let path = currentLogFileLocation?.path,
           let read = try? String(contentsOfFile: path, encoding: .utf8) {
            str = read
        }
        return str
    }

    /// write to logging system and write
    /// - Parameters:
    ///   - kind: grouped tagging, we suggest use the class name
    ///   - message: message
    ///   - level: level for logging, can be used to filtering log later on
    func join(_ kind: String, _ message: String, level: DogLevel = .info) {
        // thread safe
        executionLock.lock()
        defer { executionLock.unlock() }

        // the real message to write
        let content: String
        if lastTag == kind {
            content = "* |\(level.rawValue)| \(formatter.string(from: Date()))| \(message)"
        } else {
            lastTag = kind
            content = "[\(kind)]\n* |\(level.rawValue)| \(formatter.string(from: Date()))| \(message)"
        }
        // print stdout
        dogLogger.info("\(content)")
        // check
        guard let handler = logFileHandler else {
            dogLogger.error("failed/didn't open the file handler")
            return
        }
        // write
        guard let data = content.appending("\n").data(using: .utf8) else {
            dogLogger.error("failed to create log data using utf8")
            return
        }
        // the throwing write, a full disk or a closed file must never take
        // the process down; the legacy write(_:) raises an ObjC exception
        do {
            try handler.write(contentsOf: data)
            if failedWriteCount > 0 {
                dogLogger.info("log writes recovered after \(self.failedWriteCount, privacy: .public) failure(s)")
                failedWriteCount = 0
            }
        } catch {
            // the tag line may be lost with this one, repeat it next time
            lastTag = nil
            failedWriteCount += 1
            // a full disk fails every line, report the first and then every thousandth
            if failedWriteCount == 1 || failedWriteCount % 1000 == 0 {
                dogLogger.error("failed to write log (\(self.failedWriteCount, privacy: .public) so far) to \(self.currentLogFileLocation?.path ?? "?", privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// an wrapper around describing class
    /// - Parameters:
    ///   - kind: grouped tagging, we suggest use the class name
    ///   - message: message
    ///   - level: level for logging, can be used to filtering log later on
    func join(_ kind: Any, _ message: String, level: DogLevel = .info) {
        join(String(describing: kind.self), message, level: level)
    }

    /// initialize to dir, call only once
    /// - Parameter config: configuration
    func initialization(writableDir: URL? = nil) throws {
        var dispathDir = writableDir
        if dispathDir == nil {
            dispathDir = FileManager
                .default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first
        }
        guard let dispathDir = dispathDir else {
            dogLogger.error("unable to initialize, no directory given and no documents directory")
            throw DogError.noWritableDirectory
        }
        let storeLocationDir = dispathDir
            .appendingPathComponent(Dog.dirBase, isDirectory: true)
        dogLogger.info("initializing in \(storeLocationDir.path, privacy: .public)")

        do {
            try FileManager.default.createDirectory(atPath: storeLocationDir.path,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
        } catch {
            // an existing folder is fine, the check below decides
            dogLogger.warning("failed to create \(storeLocationDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        var bool = ObjCBool(false)
        let dirValidate = FileManager
            .default
            .fileExists(atPath: storeLocationDir.path, isDirectory: &bool)
        if !(dirValidate && bool.boolValue) {
            dogLogger.error("unable to initialize, \(storeLocationDir.path, privacy: .public) is not a directory we can use")
            throw DogError.directoryUnavailable(storeLocationDir)
        }
        if !FileManager.default.isWritableFile(atPath: storeLocationDir.path) {
            // creating the file below will fail and say so, this names the cause
            dogLogger.warning("\(storeLocationDir.path, privacy: .public) is not writable by this process")
        }

        currentLogFileDirLocation = storeLocationDir

        // please keep file date name will use it later on

        var logFileLocation: URL
        do {
            let dateName = String(formatter.string(from: Date()))
            // randomized sub suffix
            var suffix = String(UUID().uuidString)
            while suffix.count > loggingRndSuffix.count {
                suffix.removeLast()
            }
            // create file name
            let name = [
                loggingPrefix, "_",
                dateName, "_",
                suffix, ".",
                loggingSuffix,
            ]
            .joined()
            #if DEBUG
                // double check
                assert(!name.contains(" "), "\(#file) \(#line) invalid log file name: \(name)")
                assert(name.count == cLogFilenameLenth, "\(#file) \(#line) invalid log file name: \(name)")
            #endif
            logFileLocation = storeLocationDir.appendingPathComponent(name)
            // for very edge case, we handle this
            try? FileManager.default.removeItem(at: logFileLocation)
        }

        // delete logs that exceed limit
        do {
            try cleanLogs()
        } catch {
            // some very bad permission issue
            dogLogger.error("failed to enumerate \(storeLocationDir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }

        // Create file now
        guard FileManager.default.createFile(atPath: logFileLocation.path, contents: nil, attributes: nil),
              let handler = FileHandle(forWritingAtPath: logFileLocation.path)
        else {
            dogLogger.error("failed to create log file at \(logFileLocation.path, privacy: .public), errno \(errno, privacy: .public)")
            throw DogError.fileUnavailable(logFileLocation)
        }
        executionLock.lock()
        let previous = logFileHandler
        logFileHandler = handler
        lastTag = nil
        failedWriteCount = 0
        currentLogFileLocation = logFileLocation
        executionLock.unlock()
        if previous != nil {
            dogLogger.info("initialization ran again, closing the previous log file")
        }
        try? previous?.close()
        dogLogger.info("log file: \(logFileLocation.path, privacy: .public)")
    }

    // TODO: Filtering Level
}
