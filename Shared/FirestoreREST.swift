import Foundation

/// Minimal Firestore + Secure Token REST client for the widget, which must not embed the Firebase SDK
/// (widget extensions have a ~30 MB memory limit).
enum FirestoreREST {
    enum RESTError: Error, CustomStringConvertible {
        case http(status: Int, body: String)
        case malformedResponse

        var description: String {
            switch self {
            case let .http(status, body): return "HTTP \(status): \(body.prefix(200))"
            case .malformedResponse: return "malformed response"
            }
        }
    }

    /// Metadata of a moment as stored in Firestore, without the image bytes.
    struct RemoteMoment: Equatable {
        let id: String
        let authorUid: String
        let kind: Moment.Kind
        let text: String?
        let createdAt: Date

        var moment: Moment {
            Moment(id: id, authorUid: authorUid, kind: kind, text: text, createdAt: createdAt, imageFileName: nil)
        }
    }

    /// How many recent moments to scan for the partner's latest one (both people post to one collection).
    static let scanLimit = 10

    // MARK: Auth

    /// Returns the session with a usable ID token, exchanging the refresh token when needed.
    static func refreshingIDToken(_ session: SharedSession, now: Date = Date()) async throws -> SharedSession {
        if session.hasValidIDToken(at: now) { return session }

        var components = URLComponents(string: "https://securetoken.googleapis.com/v1/token")!
        components.queryItems = [URLQueryItem(name: "key", value: session.apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(session.bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.httpBody = formBody(["grant_type": "refresh_token", "refresh_token": session.refreshToken])

        let data = try await send(request)
        return try applyTokenResponse(data, to: session, now: now)
    }

    static func applyTokenResponse(_ data: Data, to session: SharedSession, now: Date) throws -> SharedSession {
        struct TokenResponse: Decodable {
            let id_token: String
            let refresh_token: String
            let expires_in: String
        }
        guard let response = try? JSONDecoder().decode(TokenResponse.self, from: data),
              let lifetime = TimeInterval(response.expires_in) else {
            throw RESTError.malformedResponse
        }
        var updated = session
        updated.idToken = response.id_token
        updated.refreshToken = response.refresh_token
        updated.idTokenExpiry = now.addingTimeInterval(lifetime)
        return updated
    }

    // MARK: Moments

    /// Latest moment written by someone other than `session.uid`, without image bytes.
    static func latestPartnerMoment(_ session: SharedSession) async throws -> RemoteMoment? {
        let url = documentURL(session, path: "couples/\(session.coupleId):runQuery")
        var request = authorizedRequest(url: url, session: session)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: latestMomentsQuery())

        let data = try await send(request)
        return try parseLatestPartnerMoment(fromRunQueryResponse: data, excludingAuthor: session.uid)
    }

    static func latestMomentsQuery() -> [String: Any] {
        // Leave imageData out: it is only downloaded when the moment is actually new.
        let selectedFields: [[String: String]] = ["authorUid", "type", "text", "createdAt"].map { ["fieldPath": $0] }
        let orderBy: [String: Any] = ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
        let structuredQuery: [String: Any] = [
            "from": [["collectionId": "moments"]],
            "select": ["fields": selectedFields],
            "orderBy": [orderBy],
            "limit": scanLimit,
        ]
        return ["structuredQuery": structuredQuery]
    }

    /// Image bytes of one moment, or nil for a note.
    static func imageData(momentId: String, session: SharedSession) async throws -> Data? {
        var components = URLComponents(
            url: documentURL(session, path: "couples/\(session.coupleId)/moments/\(momentId)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "mask.fieldPaths", value: "imageData")]
        let data = try await send(authorizedRequest(url: components.url!, session: session))
        return try parseImageData(fromDocument: data)
    }

    // MARK: Parsing (pure, unit-tested)

    static func parseLatestPartnerMoment(fromRunQueryResponse data: Data,
                                         excludingAuthor uid: String) throws -> RemoteMoment? {
        guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw RESTError.malformedResponse
        }
        for result in results {
            // Results without "document" only carry a readTime (e.g. an empty collection).
            guard let document = result["document"] as? [String: Any] else { continue }
            guard let moment = parseMoment(document) else { continue }
            if moment.authorUid != uid { return moment }
        }
        return nil
    }

    static func parseMoment(_ document: [String: Any]) -> RemoteMoment? {
        guard let name = document["name"] as? String,
              let id = name.split(separator: "/").last.map(String.init),
              let fields = document["fields"] as? [String: Any],
              let authorUid = value(fields, "authorUid", "stringValue"),
              let kind = value(fields, "type", "stringValue").flatMap(Moment.Kind.init(rawValue:)),
              let createdAt = value(fields, "createdAt", "timestampValue").flatMap(parseTimestamp) else {
            return nil
        }
        return RemoteMoment(id: id, authorUid: authorUid, kind: kind,
                            text: value(fields, "text", "stringValue"), createdAt: createdAt)
    }

    static func parseImageData(fromDocument data: Data) throws -> Data? {
        guard let document = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RESTError.malformedResponse
        }
        guard let fields = document["fields"] as? [String: Any],
              let base64 = value(fields, "imageData", "bytesValue") else { return nil }
        guard let bytes = Data(base64Encoded: base64) else { throw RESTError.malformedResponse }
        return bytes
    }

    /// Firestore returns RFC 3339 timestamps with up to 9 fractional digits;
    /// ISO8601DateFormatter only accepts up to 3, so the fraction is trimmed first.
    static func parseTimestamp(_ string: String) -> Date? {
        var normalized = string
        if let dot = string.firstIndex(of: ".") {
            let afterDot = string.index(after: dot)
            let zoneStart = string[afterDot...].firstIndex { !$0.isNumber } ?? string.endIndex
            let fraction = String(string[afterDot..<zoneStart].prefix(3))
                .padding(toLength: 3, withPad: "0", startingAt: 0)
            normalized = String(string[..<dot]) + "." + fraction + String(string[zoneStart...])
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: normalized) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: Helpers

    /// application/x-www-form-urlencoded body. URLComponents is not used because it leaves "+" unescaped,
    /// which a form decoder reads as a space.
    static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)!
    }

    private static func value(_ fields: [String: Any], _ key: String, _ type: String) -> String? {
        (fields[key] as? [String: Any])?[type] as? String
    }

    /// Built from a string on purpose: appendingPathComponent could escape the ":" in ":runQuery".
    static func documentURL(_ session: SharedSession, path: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(session.projectId)/databases/(default)/documents/\(path)")!
    }

    private static func authorizedRequest(url: URL, session: SharedSession) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.idToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(session.bundleId, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        return request
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RESTError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw RESTError.http(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        return data
    }
}
