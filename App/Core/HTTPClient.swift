import Foundation

public struct HTTPHeader: Identifiable, Equatable, Codable {
    public var id = UUID()
    public var name: String
    public var value: String
    public init(name: String = "", value: String = "") { self.name = name; self.value = value }
}

public struct HTTPResult: Equatable {
    public let status: Int
    public let headers: [String: String]
    public let body: String
    public let prettyBody: String
    public let durationMS: Int
    public let byteCount: Int
}

public enum HTTPClientError: Error, LocalizedError {
    case badURL
    public var errorDescription: String? { "الرابط غير صحيح" }
}

public struct HTTPRequestSpec: Equatable {
    public var method: String
    public var urlString: String
    public var headers: [HTTPHeader]
    public var body: String
    public init(method: String = "GET", urlString: String = "https://", headers: [HTTPHeader] = [], body: String = "") {
        self.method = method; self.urlString = urlString; self.headers = headers; self.body = body
    }

    public func buildRequest() throws -> URLRequest {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme != nil, url.host != nil else { throw HTTPClientError.badURL }
        var r = URLRequest(url: url)
        r.httpMethod = method
        for h in headers where !h.name.trimmingCharacters(in: .whitespaces).isEmpty {
            r.setValue(h.value, forHTTPHeaderField: h.name)
        }
        if !body.isEmpty, method != "GET", method != "HEAD" { r.httpBody = body.data(using: .utf8) }
        return r
    }
}

public enum HTTPClient {
    public static func send(_ spec: HTTPRequestSpec, session: URLSession = .shared) async throws -> HTTPResult {
        let req = try spec.buildRequest()
        let start = Date()
        let (data, resp) = try await session.data(for: req)
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let http = resp as? HTTPURLResponse
        var headers: [String: String] = [:]
        for (k, v) in (http?.allHeaderFields ?? [:]) { headers["\(k)"] = "\(v)" }
        let text = String(data: data, encoding: .utf8) ?? "(\(data.count) بايت غير نصية)"
        let pretty = PlistTools.prettyJSON(data) ?? text
        return HTTPResult(status: http?.statusCode ?? 0, headers: headers, body: text,
                          prettyBody: pretty, durationMS: ms, byteCount: data.count)
    }
}
