import Foundation

public enum PlistValueType: String { case string, bool, int, double, date, data, array, dict }

public struct InfoPlistSummary: Equatable {
    public var bundleID: String
    public var displayName: String
    public var version: String
    public var build: String
    public var minOS: String
    public var permissions: [(String, String)]
    public var urlSchemes: [String]

    public static func == (l: InfoPlistSummary, r: InfoPlistSummary) -> Bool {
        l.bundleID == r.bundleID && l.displayName == r.displayName && l.version == r.version &&
        l.build == r.build && l.minOS == r.minOS && l.urlSchemes == r.urlSchemes &&
        l.permissions.map { $0.0 } == r.permissions.map { $0.0 }
    }
}

public enum PlistTools {
    /// Parse any plist data into a Foundation object.
    public static func read(_ data: Data) -> Any? {
        try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }

    public static func summarize(_ dict: [String: Any]) -> InfoPlistSummary {
        var perms: [(String, String)] = []
        for (k, v) in dict where k.hasPrefix("NS") && k.hasSuffix("UsageDescription") {
            perms.append((k, (v as? String) ?? ""))
        }
        perms.sort { $0.0 < $1.0 }
        var schemes: [String] = []
        if let types = dict["CFBundleURLTypes"] as? [[String: Any]] {
            for t in types { schemes.append(contentsOf: (t["CFBundleURLSchemes"] as? [String]) ?? []) }
        }
        let name = (dict["CFBundleDisplayName"] as? String) ?? (dict["CFBundleName"] as? String) ?? ""
        return InfoPlistSummary(
            bundleID: (dict["CFBundleIdentifier"] as? String) ?? "",
            displayName: name,
            version: (dict["CFBundleShortVersionString"] as? String) ?? "",
            build: (dict["CFBundleVersion"] as? String) ?? "",
            minOS: (dict["MinimumOSVersion"] as? String) ?? (dict["LSMinimumSystemVersion"] as? String) ?? "",
            permissions: perms,
            urlSchemes: schemes)
    }

    /// Set a top-level string field and return re-serialized xml plist data.
    public static func setString(_ dict: inout [String: Any], key: String, value: String) {
        dict[key] = value
    }

    public static func serialize(_ object: Any, format: PropertyListSerialization.PropertyListFormat = .xml) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: object, format: format, options: 0)
    }

    /// Pretty JSON string for any JSON-compatible object.
    public static func prettyJSON(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
        else { return nil }
        return String(data: out, encoding: .utf8)
    }

    public static func isValidJSON(_ text: String) -> Bool {
        guard let d = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])) != nil
    }
}
