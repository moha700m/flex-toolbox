import Foundation

public struct FileNode: Identifiable, Equatable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int
    public let modified: Date?
}

public enum FileBrowser {
    public static func list(_ url: URL) throws -> [FileNode] {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
        return try urls.map { u in
            let v = try u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return FileNode(url: u, name: u.lastPathComponent, isDirectory: v.isDirectory == true,
                            size: v.fileSize ?? 0, modified: v.contentModificationDate)
        }.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    public static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    public static var library: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }
    public static var tmp: URL { FileManager.default.temporaryDirectory }

    public static func delete(_ url: URL) throws { try FileManager.default.removeItem(at: url) }

    public static func writeText(_ text: String, to url: URL) throws {
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    public static func kind(of url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "plist": return "plist"
        case "json": return "json"
        case "sqlite", "db", "sqlite3": return "sqlite"
        case "ipa": return "ipa"
        case "txt", "md", "log", "csv", "xml", "html", "js", "css", "swift": return "text"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "image"
        default: return "binary"
        }
    }
}
