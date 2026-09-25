import PhotosUI
import SwiftUI

/// Debug screen for the week-1 spike. Replaced by the real Home screen later.
struct SpikeView: View {
    @ObservedObject var model: SpikeModel
    @Environment(\.scenePhase) private var scenePhase

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: UIImage?
    @State private var caption = ""

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                sendSection
                partnerSection
                logSection
            }
            .navigationTitle("spike.title")
        }
        .tint(Palette.terracotta)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.reloadLog() }
        }
        .onChange(of: photoItem) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var statusSection: some View {
        Section {
            switch model.status {
            case .starting:
                HStack {
                    ProgressView()
                    Text("spike.status.starting")
                }
            case .missingConfig:
                Text("spike.status.missingConfig")
                    .foregroundStyle(.red)
            case let .signedIn(uid):
                Text("spike.status.signedIn \(String(uid.prefix(8)))")
            case let .failed(message):
                Text("spike.status.failed \(message)")
                    .foregroundStyle(.red)
            }
        }
    }

    private var sendSection: some View {
        Section("spike.send.header") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("spike.send.pickPhoto", systemImage: "photo.on.rectangle")
            }
            if let photoPreview {
                Image(uiImage: photoPreview)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button("spike.send.removePhoto", role: .destructive) {
                    photoItem = nil
                    photoData = nil
                    photoPreview = nil
                }
            }
            TextField("spike.send.placeholder", text: $caption, axis: .vertical)
                .font(.system(.body, design: .serif))
                .onChange(of: caption) { _, newValue in
                    if newValue.count > SpikeModel.maxNoteLength {
                        caption = String(newValue.prefix(SpikeModel.maxNoteLength))
                    }
                }
            HStack {
                Text(verbatim: "\(caption.count)/\(SpikeModel.maxNoteLength)")
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                Button {
                    Task { await send() }
                } label: {
                    if model.isSending {
                        ProgressView()
                    } else {
                        Label("spike.send.button", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSend)
            }
            if model.lastSentAt != nil {
                Text("spike.send.success")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            if let error = model.sendError {
                Text(verbatim: error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var partnerSection: some View {
        Section("spike.partner.header") {
            if let moment = model.partnerMoment {
                if let image = model.partnerImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if let text = moment.text, !text.isEmpty {
                    Text(verbatim: text)
                        .font(.system(.title3, design: .serif))
                }
                Text(moment.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
            } else {
                Text("spike.partner.empty")
                    .foregroundStyle(Palette.secondaryText)
            }
            Button("spike.widget.reload") {
                model.reloadWidget()
            }
        }
    }

    private var logSection: some View {
        Section {
            if model.refreshLog.isEmpty {
                Text("spike.log.empty")
                    .foregroundStyle(Palette.secondaryText)
            }
            ForEach(model.refreshLog.prefix(50)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, format: .dateTime.day().month().hour().minute().second())
                        .font(.caption.monospacedDigit())
                    Text(verbatim: "[\(entry.source)] \(entry.result)")
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        } header: {
            HStack {
                Text("spike.log.header")
                Spacer()
                Button("spike.log.reload") { model.reloadLog() }
                    .font(.caption)
            }
        } footer: {
            Text("spike.log.footer")
        }
    }

    // MARK: Actions

    private var canSend: Bool {
        let hasContent = photoData != nil || !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasContent && model.uid != nil && !model.isSending
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else {
            photoData = nil
            photoPreview = nil
            return
        }
        photoData = data
        photoPreview = ImageResizer.downsampledJPEG(from: data).flatMap(UIImage.init(data:))
    }

    private func send() async {
        let sent: Bool
        if let photoData {
            sent = await model.sendPhoto(photoData, caption: caption)
        } else {
            sent = await model.sendNote(caption)
        }
        if sent {
            photoItem = nil
            photoData = nil
            photoPreview = nil
            caption = ""
        }
    }
}
