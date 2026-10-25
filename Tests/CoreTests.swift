import XCTest

final class CoreTests: XCTestCase {

    func testHexDumpLayout() {
        let data = Data([0x48, 0x61, 0x71, 0x71, 0x69, 0x00, 0x01, 0xff] + Array(repeating: 0x41, count: 20))
        let dump = HexDump.make(data)
        XCTAssertTrue(dump.contains("00000000"))
        XCTAssertTrue(dump.contains("48 61 71 71"))
        XCTAssertTrue(dump.contains("|Haqqi"))
    }

    func testPlistRoundTripAndSummary() throws {
        let dict: [String: Any] = [
            "CFBundleIdentifier": "com.moha700m.demo",
            "CFBundleDisplayName": "تجربة",
            "CFBundleShortVersionString": "2.1",
            "CFBundleVersion": "9",
            "MinimumOSVersion": "17.0",
            "NSCameraUsageDescription": "نحتاج الكاميرا",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["demo", "flex"]]]
        ]
        let data = try XCTUnwrap(PlistTools.serialize(dict))
        let back = try XCTUnwrap(PlistTools.read(data) as? [String: Any])
        let s = PlistTools.summarize(back)
        XCTAssertEqual(s.bundleID, "com.moha700m.demo")
        XCTAssertEqual(s.displayName, "تجربة")
        XCTAssertEqual(s.version, "2.1")
        XCTAssertEqual(s.minOS, "17.0")
        XCTAssertEqual(s.permissions.count, 1)
        XCTAssertEqual(s.urlSchemes, ["demo", "flex"])
    }

    func testPrettyJSON() {
        let raw = #"{"b":1,"a":[true,"x"]}"#.data(using: .utf8)!
        let pretty = PlistTools.prettyJSON(raw)!
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertTrue(PlistTools.isValidJSON(pretty))
        XCTAssertFalse(PlistTools.isValidJSON("{bad"))
    }

    func testHTTPRequestBuild() throws {
        var spec = HTTPRequestSpec(method: "POST", urlString: "https://example.com/api",
                                   headers: [HTTPHeader(name: "X-Test", value: "1")], body: #"{"ok":true}"#)
        let req = try spec.buildRequest()
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Test"), "1")
        XCTAssertEqual(req.httpBody, #"{"ok":true}"#.data(using: .utf8))
        spec.urlString = "not a url"
        XCTAssertThrowsError(try spec.buildRequest())
    }

    func testIPAOpenEditExport() throws {
        // Build a minimal fake IPA: Payload/Demo.app/Info.plist + hello.txt
        let fm = FileManager.default
        let stage = fm.temporaryDirectory.appendingPathComponent("ipa-stage-\(UUID().uuidString)", isDirectory: true)
        let payload = stage.appendingPathComponent("Payload")
        let app = payload.appendingPathComponent("Demo.app")
        try fm.createDirectory(at: app, withIntermediateDirectories: true)
        let dict: [String: Any] = [
            "CFBundleIdentifier": "com.demo.app",
            "CFBundleDisplayName": "Demo",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "MinimumOSVersion": "15.0",
            "CFBundleExecutable": "Demo"
        ]
        try XCTUnwrap(PlistTools.serialize(dict)).write(to: app.appendingPathComponent("Info.plist"))
        try "hello".data(using: .utf8)!.write(to: app.appendingPathComponent("hello.txt"))
        try fm.createDirectory(at: app.appendingPathComponent("Frameworks"), withIntermediateDirectories: true)
        try Data([0xCA, 0xFE]).write(to: app.appendingPathComponent("Frameworks/Extra.dylib"))

        let ipaURL = fm.temporaryDirectory.appendingPathComponent("Demo.ipa")
        try? fm.removeItem(at: ipaURL)
        try fm.zipItem(at: payload, to: ipaURL, shouldKeepParent: true)

        let bundle = try IPATools.open(ipaURL)
        XCTAssertEqual(bundle.summary.bundleID, "com.demo.app")
        XCTAssertEqual(bundle.summary.displayName, "Demo")
        XCTAssertTrue(bundle.entries.contains { $0.path.hasSuffix("hello.txt") })
        XCTAssertTrue(bundle.dylibs.contains { $0.hasSuffix("Extra.dylib") })

        var edited = bundle.infoDict
        edited["CFBundleDisplayName"] = "معدّل"
        edited["CFBundleIdentifier"] = "com.demo.edited"
        try IPATools.writeInfoPlist(bundle, dict: edited)

        try IPATools.deleteFile(in: bundle, relativePath: "Payload/Demo.app/hello.txt")
        let out = try IPATools.export(bundle, named: "Demo-edited.ipa")
        XCTAssertTrue(fm.fileExists(atPath: out.path))
        XCTAssertGreaterThan((try out.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0, 100)

        // Re-open exported IPA and verify edits stuck.
        let again = try IPATools.open(out)
        XCTAssertEqual(again.summary.displayName, "معدّل")
        XCTAssertEqual(again.summary.bundleID, "com.demo.edited")
        XCTAssertFalse(again.entries.contains { $0.path.hasSuffix("hello.txt") })

        IPATools.cleanup(bundle)
        IPATools.cleanup(again)
        try? fm.removeItem(at: stage)
        try? fm.removeItem(at: ipaURL)
        try? fm.removeItem(at: out)
    }

    func testSQLiteRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE notes(id INTEGER PRIMARY KEY, body TEXT); INSERT INTO notes(body) VALUES ('مرحبا'), ('world');", nil, nil, nil), SQLITE_OK)
        let tables = try SQLiteBrowser.tables(at: url)
        XCTAssertEqual(tables.map(\.name), ["notes"])
        let preview = try SQLiteBrowser.preview(at: url, table: "notes")
        XCTAssertEqual(preview.columns, ["id", "body"])
        XCTAssertEqual(preview.rows.count, 2)
        XCTAssertEqual(preview.rows[0][1], "مرحبا")
        try? FileManager.default.removeItem(at: url)
    }

    func testFileBrowserKind() {
        XCTAssertEqual(FileBrowser.kind(of: URL(fileURLWithPath: "/a/b.plist")), "plist")
        XCTAssertEqual(FileBrowser.kind(of: URL(fileURLWithPath: "/a/b.JSON")), "json")
        XCTAssertEqual(FileBrowser.kind(of: URL(fileURLWithPath: "/a/b.sqlite")), "sqlite")
        XCTAssertEqual(FileBrowser.kind(of: URL(fileURLWithPath: "/a/b.bin")), "binary")
    }

    func testHumanSize() {
        XCTAssertEqual(IPATools.humanSize(500), "500 ب")
        XCTAssertTrue(IPATools.humanSize(2048).contains("كب"))
    }
}

import SQLite3
import ZIPFoundation
