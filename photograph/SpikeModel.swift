import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import UIKit
import WidgetKit

/// Week-1 spike: send a moment, receive the partner's latest one, and keep the widget's App Group cache fresh.
@MainActor
final class SpikeModel: ObservableObject {
    enum Status: Equatable {
        case starting
        case missingConfig
        case signedIn(uid: String)
        case failed(String)
    }

    static let maxNoteLength = 80

    @Published private(set) var status: Status = .starting
    @Published private(set) var partnerMoment: Moment?
    @Published private(set) var partnerImage: UIImage?
    @Published private(set) var refreshLog: [RefreshLogEntry] = []
    @Published private(set) var isSending = false
    @Published private(set) var lastSentAt: Date?
    @Published var sendError: String?

    private var listener: ListenerRegistration?

    var uid: String? {
        if case let .signedIn(uid) = status { return uid }
        return nil
    }

    private var momentsCollection: CollectionReference {
        Firestore.firestore()
            .collection("couples").document(AppGroup.spikeCoupleId)
            .collection("moments")
    }

    // MARK: Lifecycle

    func start() async {
        showCachedMoment()
        reloadLog()
        guard listener == nil else { return }
        guard FirebaseApp.app() != nil else {
            status = .missingConfig
            return
        }
        do {
            let user: User
            if let current = Auth.auth().currentUser {
                user = current
            } else {
                user = try await Auth.auth().signInAnonymously().user
            }
            saveSession(for: user)
            status = .signedIn(uid: user.uid)
            listenForPartnerMoments(uid: user.uid)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func reloadLog() {
        refreshLog = SharedStore.loadRefreshLog()
    }

    func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Hands the widget what it needs to call Firestore REST as this user.
    private func saveSession(for user: User) {
        guard let options = FirebaseApp.app()?.options,
              let apiKey = options.apiKey,
              let projectId = options.projectID,
              let refreshToken = user.refreshToken else { return }
        let existing = SharedStore.loadSession()
        guard existing?.uid != user.uid || existing?.refreshToken != refreshToken else { return }
        SharedStore.saveSession(SharedSession(
            uid: user.uid,
            coupleId: AppGroup.spikeCoupleId,
            apiKey: apiKey,
            projectId: projectId,
            bundleId: Bundle.main.bundleIdentifier ?? "hwee.photograph",
            refreshToken: refreshToken,
            idToken: nil,
            idTokenExpiry: nil
        ))
    }

    // MARK: Receiving

    private func listenForPartnerMoments(uid: String) {
        listener = momentsCollection
            .order(by: "createdAt", descending: true)
            .limit(to: FirestoreREST.scanLimit)
            .addSnapshotListener { [weak self] snapshot, error in
                // Firestore delivers snapshot callbacks on the main queue.
                MainActor.assumeIsolated {
                    self?.handle(snapshot: snapshot, error: error, uid: uid)
                }
            }
    }

    private func handle(snapshot: QuerySnapshot?, error: Error?, uid: String) {
        if let error {
            SharedStore.appendRefreshLog(source: "app", result: "listener error: \(error.localizedDescription)")
            reloadLog()
            return
        }
        guard let document = snapshot?.documents.first(where: { $0.get("authorUid") as? String != uid }) else {
            return
        }
        let data = document.data(with: .estimate)
        guard let authorUid = data["authorUid"] as? String,
              let kind = (data["type"] as? String).flatMap(Moment.Kind.init(rawValue:)) else { return }

        if document.documentID != SharedStore.loadLatestMoment()?.id {
            let moment = Moment(
                id: document.documentID,
                authorUid: authorUid,
                kind: kind,
                text: data["text"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                imageFileName: nil
            )
            do {
                try SharedStore.saveLatestMoment(moment, imageData: data["imageData"] as? Data)
                SharedStore.appendRefreshLog(source: "app", result: "NEW \(kind.rawValue) via listener")
                // Reloads requested while the app is in the foreground do not count against the widget budget.
                reloadWidget()
            } catch {
                SharedStore.appendRefreshLog(source: "app", result: "save error: \(error)")
            }
        }
        showCachedMoment()
        reloadLog()
    }

    private func showCachedMoment() {
        let moment = SharedStore.loadLatestMoment()
        partnerMoment = moment
        partnerImage = moment
            .flatMap(SharedStore.imageURL(for:))
            .flatMap { UIImage(contentsOfFile: $0.path) }
    }

    // MARK: Sending

    func sendPhoto(_ original: Data, caption: String) async -> Bool {
        guard let jpeg = ImageResizer.jpegForUpload(from: original) else {
            sendError = String(localized: "spike.error.image")
            return false
        }
        return await send(kind: .photo, text: caption, imageData: jpeg)
    }

    func sendNote(_ text: String) async -> Bool {
        await send(kind: .note, text: text, imageData: nil)
    }

    private func send(kind: Moment.Kind, text: String, imageData: Data?) async -> Bool {
        guard let uid else { return false }
        isSending = true
        defer { isSending = false }

        var payload: [String: Any] = [
            "authorUid": uid,
            "type": kind.rawValue,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            payload["text"] = String(trimmed.prefix(Self.maxNoteLength))
        }
        if let imageData {
            payload["imageData"] = imageData
        }

        do {
            try await momentsCollection.document().setData(payload)
            lastSentAt = Date()
            sendError = nil
            return true
        } catch {
            sendError = error.localizedDescription
            return false
        }
    }
}
