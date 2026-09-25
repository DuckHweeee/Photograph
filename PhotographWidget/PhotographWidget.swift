import SwiftUI
import UIKit
import WidgetKit

struct MomentEntry: TimelineEntry {
    let date: Date
    let moment: Moment?
    let image: UIImage?

    static let empty = MomentEntry(date: Date(), moment: nil, image: nil)

    init(date: Date, moment: Moment?, image: UIImage?) {
        self.date = date
        self.moment = moment
        self.image = image
    }

    init(moment: Moment?) {
        self.date = Date()
        self.moment = moment
        self.image = moment
            .flatMap(SharedStore.imageURL(for:))
            .flatMap { UIImage(contentsOfFile: $0.path) }
    }
}

struct MomentProvider: TimelineProvider {
    /// Requested cadence; iOS decides the real one (that is what the spike measures).
    static let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> MomentEntry {
        .empty
    }

    func getSnapshot(in context: Context, completion: @escaping (MomentEntry) -> Void) {
        completion(MomentEntry(moment: SharedStore.loadLatestMoment()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MomentEntry>) -> Void) {
        Task {
            let moment = await MomentLoader.refresh()
            let next = Date().addingTimeInterval(Self.refreshInterval)
            completion(Timeline(entries: [MomentEntry(moment: moment)], policy: .after(next)))
        }
    }
}

struct PhotographWidget: Widget {
    let kind = "PhotographWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MomentProvider()) { entry in
            MomentWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct PhotographWidgetBundle: WidgetBundle {
    var body: some Widget {
        PhotographWidget()
    }
}
