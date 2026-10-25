import Foundation
import SQLite3

public struct SQLiteTable: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
}

public struct SQLiteQueryResult: Equatable {
    public let columns: [String]
    public let rows: [[String]]
}

public enum SQLiteBrowser {
    public static func tables(at url: URL) throws -> [SQLiteTable] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw NSError(domain: "sqlite", code: 1, userInfo: [NSLocalizedDescriptionKey: "ما قدرت أفتح قاعدة البيانات"])
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [SQLiteTable] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                out.append(SQLiteTable(name: String(cString: c)))
            }
        }
        return out
    }

    public static func preview(at url: URL, table: String, limit: Int = 100) throws -> SQLiteQueryResult {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw NSError(domain: "sqlite", code: 1)
        }
        defer { sqlite3_close(db) }
        // Quote the identifier safely (double any internal quotes).
        let safe = table.replacingOccurrences(of: "\"", with: "\"\"")
        let sql = "SELECT * FROM \"\(safe)\" LIMIT \(limit);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            let msg = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "sqlite", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        defer { sqlite3_finalize(stmt) }
        let colCount = Int(sqlite3_column_count(stmt))
        var cols: [String] = []
        for i in 0..<colCount {
            cols.append(String(cString: sqlite3_column_name(stmt, Int32(i))))
        }
        var rows: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<colCount {
                if let t = sqlite3_column_text(stmt, Int32(i)) { row.append(String(cString: t)) }
                else { row.append("") }
            }
            rows.append(row)
        }
        return SQLiteQueryResult(columns: cols, rows: rows)
    }
}
