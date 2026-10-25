import Foundation

public struct FileItem: Identifiable, Hashable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date?
}

public enum FileKind: Equatable { case plist, json, sqlite, text, image, ipa, binary, folder }

public enum FileTools {
    public static func
