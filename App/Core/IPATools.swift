import Foundation
import ZIPFoundation

public struct IPAFileEntry: Identifiable, Equatable {
    public var id: String { path }
    public let path: String
    public let size: Int
    public var isDirectory: Bool { path.hasSuffix("/") }
}

public struct IPABundle: Equatable {
    public let workDir: URL
    public let appDir: URL
    public let appName: String
    public let entries: [IPAFileEntry]
    public var infoDict: [String: Any]
    public var summary: InfoPlistSummary
    public var frameworks: [String]
    public var dylibs: [String]
    public var entitlementsXML: String?
}

public enum IPAError: Error, LocalizedError {
    case notIPA, noPayload, noApp, badPlist, writeFailed
    public var errorDescription: String? {
        switch self {
        case .notIPA: return "الملف مو IPA"
        case .noPayload: return "ما فيه مجلد Payload"
        case .noApp: return "ما فيه تطبيق داخل الـ IPA"
        case .badPlist: return "Info.plist تالف"
        case .writeFailed: return "فشل الحفظ"
        }
    }
}

public enum IPATools {
    /// Unzip an IPA into a temp work dir and parse the first .app.
    public static func open(_ ipaURL: URL, into root: URL = FileManager.default.temporaryDirectory) throws -> IPABundle {
        let scoped = ipaURL.startAccessingSecurityScopedResource()
        defer { if scoped { ipaURL.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let work = root.appendingPathComponent("flex-ipa-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        try fm.unzipItem(at: ipaURL, to: work)
        let payload = work.appendingPathComponent("Payload")
        guard fm.fileExists(atPath: payload.path) else { throw IPAError.noPayload }
        let apps = try fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let app = apps.first else { throw IPAError.noApp }
        let plistURL = app.appendingPathComponent("Info.plist")
        let pdata = try Data(contentsOf: plistURL)
        guard let dict = PlistTools.read(pdata) as? [String: Any] else { throw IPAError.badPlist }
        var entries: [IPAFileEntry] = []
        if let enumerator = fm.enumerator(at: work, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                let vals = try url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                let rel = url.path.replacingOccurrences(of: work.path + "/", with: "")
                let size = vals.isDirectory == true ? 0 : (vals.fileSize ?? 0)
                let path = (vals.isDirectory == true && !rel.hasSuffix("/")) ? rel + "/" : rel
                entries.append(IPAFileEntry(path: path, size: size))
            }
        }
        entries.sort { $0.path < $1.path }
        let frameworks = entries.filter { $0.path.contains(".app/Frameworks/") && $0.path.hasSuffix(".framework/") }.map { $0.path }
        let dylibs = entries.filter {
            let p = $0.path
            return (p.hasSuffix(".dylib") || p.hasSuffix(".framework/")) && p.contains(".app/")
        }.map { $0.path }
        let ents = readEntitlements(from: app)
        return IPABundle(workDir: work, appDir: app, appName: app.lastPathComponent,
                         entries: entries, infoDict: dict, summary: PlistTools.summarize(dict),
                         frameworks: frameworks, dylibs: dylibs, entitlementsXML: ents)
    }

    public static func readEntitlements(from app: URL) -> String? {
        // Prefer embedded.mobileprovision's entitlements if present; otherwise nil (unsigned IPAs usually have none).
        let provision = app.appendingPathComponent("embedded.mobileprovision")
        guard let data = try? Data(contentsOf: provision),
              let text = String(data: data, encoding: .ascii) else { return nil }
        guard let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>") else { return nil }
        return String(text[start.lowerBound..<end.upperBound])
    }

    public static func writeInfoPlist(_ bundle: IPABundle, dict: [String: Any]) throws {
        guard let data = PlistTools.serialize(dict) else { throw IPAError.writeFailed }
        try data.write(to: bundle.appDir.appendingPathComponent("Info.plist"), options: .atomic)
    }

    public static func deleteFile(in bundle: IPABundle, relativePath: String) throws {
        let url = bundle.workDir.appendingPathComponent(relativePath)
        try FileManager.default.removeItem(at: url)
    }

    public static func addFile(in bundle: IPABundle, from source: URL, relativePath: String) throws {
        let dest = bundle.workDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
        try FileManager.default.copyItem(at: source, to: dest)
    }

    /// Re-zip Payload into a new IPA in Documents and return its URL.
    public static func export(_ bundle: IPABundle, named: String) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let out = docs.appendingPathComponent(named.hasSuffix(".ipa") ? named : named + ".ipa")
        if fm.fileExists(atPath: out.path) { try fm.removeItem(at: out) }
        // ZIPFoundation zipItem with Payload folder as root content.
        let payload = bundle.workDir.appendingPathComponent("Payload")
        // Create an intermediate folder so the archive root is Payload/
        let staging = docs.appendingPathComponent(".flex-stage-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        let stagedPayload = staging.appendingPathComponent("Payload")
        try fm.copyItem(at: payload, to: stagedPayload)
        try fm.zipItem(at: stagedPayload, to: out, shouldKeepParent: true)
        try? fm.removeItem(at: staging)
        return out
    }

    public static func cleanup(_ bundle: IPABundle) {
        try? FileManager.default.removeItem(at: bundle.workDir)
    }

    public static func humanSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) ب" }
        if bytes < 1024 * 1024 { return String(format: "%.1f كب", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f مب", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.2f جب", Double(bytes) / (1024 * 1024 * 1024))
    }
}
