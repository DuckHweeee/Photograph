import Foundation

/// File-based storage in the App Group container, shared by the app and the widget.
enum SharedStore {
    private static let sessionFile = "session.json"
    private static let latestMomentFile = "latest-moment.json"
    private static let refreshLogFile = "refresh-log.json"
    private static let maxLogEntries = 200

    // The widget must be able to read these while the phone is locked (after first unlock).
    private static let writeOptions: Data.WritingOptions = [
        .atomic, .completeFileProtectionUntilFirstUserAuthentication,
    ]

    enum StoreError: Error {
        case appGroupUnavailable
        case imageDownsampleFailed
    }

    // MARK: Session

    static func loadSession() -> SharedSession? {
        read(SharedSession.self, from: sessionFile)
    }

    static func saveSession(_ session: SharedSession) {
        write(session, to: sessionFile)
    }

    // MARK: Latest moment

    static func loadLatestMoment() -> Moment? {
        read(Moment.self, from: latestMomentFile)
    }

    /// Stores the partner's latest moment. The image is always downsampled to
    /// `ImageResizer.maxPixelSize` before it touches the App Group, whatever the sender did.
    @discardableResult
    static func saveLatestMoment(_ moment: Moment, imageData: Data?) throws -> Moment {
        guard let container = AppGroup.containerURL else { throw StoreError.appGroupUnavailable }

        var stored = moment
        stored.imageFileName = nil
        if let imageData {
            guard let jpeg = ImageResizer.downsampledJPEG(from: imageData) else {
                throw StoreError.imageDownsampleFailed
            }
            let fileName = "moment-\(moment.id).jpg"
            try jpeg.write(to: container.appendingPathComponent(fileName), options: writeOptions)
            stored.imageFileName = fileName
        }

        let previous = loadLatestMoment()
        write(stored, to: latestMomentFile)

        // Keep only the current image on disk.
        if let oldFile = previous?.imageFileName, oldFile != stored.imageFileName {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(oldFile))
        }
        return stored
    }

    static func imageURL(for moment: Moment) -> URL? {
        guard let fileName = moment.imageFileName else { return nil }
        return AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    // MARK: Refresh log (spike measurement)

    static func appendRefreshLog(source: String, result: String) {
        var entries = loadRefreshLog()
        entries.insert(RefreshLogEntry(date: Date(), source: source, result: result), at: 0)
        write(Array(entries.prefix(maxLogEntries)), to: refreshLogFile)
    }

    /// Newest first.
    static func loadRefreshLog() -> [RefreshLogEntry] {
        read([RefreshLogEntry].self, from: refreshLogFile) ?? []
    }

    // MARK: Helpers

    private static func read<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        guard let url = AppGroup.containerURL?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to fileName: String) {
        guard let url = AppGroup.containerURL?.appendingPathComponent(fileName),
              let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: writeOptions)
    }
}
