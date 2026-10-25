import Foundation

public enum HexDump {
    /// Classic xxd-style hex + ascii, capped at `maxBytes`.
    public static func make(_ data: Data, maxBytes: Int = 64 * 1024) -> String {
        let slice = [UInt8](data.prefix(maxBytes))
        var out = String()
        out.reserveCapacity(slice.count * 4)
        var offset = 0
        for chunk in stride(from: 0, to: slice.count, by: 16) {
            let end = min(chunk + 16, slice.count)
            let row = slice[chunk..<end]
            var hex = ""
            var ascii = ""
            for (i, b) in row.enumerated() {
                hex += String(format: "%02x ", b)
                if i == 7 { hex += " " }
                ascii += (b >= 0x20 && b < 0x7f) ? String(UnicodeScalar(b)) : "."
            }
            hex = hex.padding(toLength: 50, withPad: " ", startingAt: 0)
            out += String(format: "%08x  %@ |%@|\n", offset, hex, ascii)
            offset += 16
        }
        if data.count > maxBytes { out += "\n… (\(data.count - maxBytes) بايت إضافية غير معروضة)" }
        return out
    }
}
