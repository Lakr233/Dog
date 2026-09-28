@testable import Dog
import XCTest

final class DogTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        Dog.shared.maximumLogCount = 128
        try? FileManager.default.removeItem(at: directory)
    }

    func testExample() throws {
        try Dog.shared.initialization(writableDir: directory)
        Dog.shared.join(self, "Hello World!", level: .info)
        XCTAssertTrue(Dog.shared.obtainCurrentLogContent().contains("Hello World!"))
    }

    /// A failed write, as on a full disk, must not raise an exception.
    func testWriteFailureDoesNotCrash() throws {
        try Dog.shared.initialization(writableDir: directory)
        try Dog.shared.logFileHandler?.close()
        Dog.shared.join("Test", "lost", level: .error)
        Dog.shared.join("Test", "lost again", level: .error)
        XCTAssertEqual(Dog.shared.failedWriteCount, 2)

        // initializing again recovers and repeats the tag line
        try Dog.shared.initialization(writableDir: directory)
        XCTAssertEqual(Dog.shared.failedWriteCount, 0)
        Dog.shared.join("Test", "kept", level: .info)
        XCTAssertTrue(Dog.shared.obtainCurrentLogContent().hasPrefix("[Test]\n"))
    }

    func testInitializationThrowsWhenTheDirectoryIsAFile() throws {
        let file = directory.appendingPathComponent("Journal")
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data()))
        XCTAssertThrowsError(try Dog.shared.initialization(writableDir: directory))
    }

    func testCleanLogsKeepsTheNewestAndLeavesOtherFiles() throws {
        let journal = directory.appendingPathComponent("Journal", isDirectory: true)
        try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: true)
        let names = (1 ... 5).map { "Dog_2021-03-0\($0)_22-10-43_ACAF51D\($0).log" }
        for name in names + ["notes.txt"] {
            FileManager.default.createFile(atPath: journal.appendingPathComponent(name).path, contents: Data())
        }
        Dog.shared.maximumLogCount = 3
        try Dog.shared.initialization(writableDir: directory)

        let left = try FileManager.default.contentsOfDirectory(atPath: journal.path)
        XCTAssertTrue(left.contains("notes.txt"))
        XCTAssertFalse(left.contains(names[0]))
        XCTAssertFalse(left.contains(names[1]))
        XCTAssertTrue(left.contains(names[2]))
        XCTAssertTrue(left.contains(names[4]))
    }

    /// File names are parsed back, so the user's calendar must not change them.
    func testFormatterIgnoresTheUserLocale() throws {
        let formatter = Dog.shared.formatter
        XCTAssertEqual(formatter.locale.identifier, "en_US_POSIX")
        let date = try XCTUnwrap(formatter.date(from: "2021-03-01_22-10-43"))
        XCTAssertEqual(formatter.string(from: date), "2021-03-01_22-10-43")
    }
}
