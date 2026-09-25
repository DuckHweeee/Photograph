import Foundation

/// Pulls the partner's latest moment over REST and caches it in the App Group.
/// Every run is written to the refresh log so the spike can measure real refresh cadence.
enum MomentLoader {
    static func refresh() async -> Moment? {
        let cached = SharedStore.loadLatestMoment()
        guard let stored = SharedStore.loadSession() else {
            SharedStore.appendRefreshLog(source: "widget", result: "no session (open the app once)")
            return cached
        }

        do {
            let session = try await FirestoreREST.refreshingIDToken(stored)
            if session != stored { SharedStore.saveSession(session) }

            guard let remote = try await FirestoreREST.latestPartnerMoment(session) else {
                SharedStore.appendRefreshLog(source: "widget", result: "no partner moment yet")
                return cached
            }
            if remote.id == cached?.id {
                SharedStore.appendRefreshLog(source: "widget", result: "no change")
                return cached
            }

            let imageData = remote.kind == .photo
                ? try await FirestoreREST.imageData(momentId: remote.id, session: session)
                : nil
            let saved = try SharedStore.saveLatestMoment(remote.moment, imageData: imageData)
            let delay = Int(Date().timeIntervalSince(remote.createdAt))
            SharedStore.appendRefreshLog(source: "widget", result: "NEW \(remote.kind.rawValue) (sent \(delay)s ago)")
            return saved
        } catch {
            SharedStore.appendRefreshLog(source: "widget", result: "error: \(error)")
            return cached
        }
    }
}
