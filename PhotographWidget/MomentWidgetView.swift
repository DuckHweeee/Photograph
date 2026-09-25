import SwiftUI
import UIKit
import WidgetKit

struct MomentWidgetView: View {
    let entry: MomentEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) { Palette.cream }
    }

    @ViewBuilder
    private var content: some View {
        if let moment = entry.moment {
            if let image = entry.image {
                photo(image, moment: moment)
            } else {
                note(moment)
            }
        } else {
            empty
        }
    }

    private func photo(_ image: UIImage, moment: Moment) -> some View {
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    if family != .systemSmall, let text = moment.text, !text.isEmpty {
                        Text(text)
                            .font(.system(.subheadline, design: .serif))
                            .lineLimit(2)
                    }
                    Text(moment.createdAt, style: .relative)
                        .font(.system(.caption2, design: .rounded))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 3)
                .padding(10)
            }
    }

    private func note(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(moment.text ?? "")
                .font(.system(family == .systemSmall ? .body : .title3, design: .serif))
                .foregroundStyle(Palette.cocoa)
                .lineSpacing(4)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text(moment.createdAt, style: .relative)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
    }

    private var empty: some View {
        Text("widget.empty")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
            .padding(14)
    }
}
