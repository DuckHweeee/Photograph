import Foundation

enum AppGroup {
    static let identifier = "group.hwee.photograph"

    /// Hardcoded couple used by the week-1 spike, before pairing (F1) exists.
    static let spikeCoupleId = "spike"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}

struct Moment: Codable, Equatable {
    enum Kind: String, Codable {
        case photo
        case note
    }

    let id: String
    let authorUid: String
    let kind: Kind
    let text: String?
    let createdAt: Date
    /// File name of the downsampled image inside the App Group container, if any.
    var imageFileName: String?
}

/// Everything the widget needs to call Firestore over REST on behalf of the signed-in user.
/// Written by the app after sign-in, read (and token-refreshed) by the widget.
struct SharedSession: Codable, Equatable {
    var uid: String
    var coupleId: String
    var apiKey: String
    var projectId: String
    /// Bundle ID of the app, sent as X-Ios-Bundle-Identifier so bundle-restricted API keys still work.
    var bundleId: String
    var refreshToken: String
    var idToken: String?
    var idTokenExpiry: Date?

    func hasValidIDToken(at now: Date = Date()) -> Bool {
        guard idToken != nil, let expiry = idTokenExpiry else { return false }
        // Keep a margin so the token does not expire mid-request.
        return expiry.timeIntervalSince(now) > 60
    }
}

struct RefreshLogEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    let date: Date
    let source: String
    let result: String
}
