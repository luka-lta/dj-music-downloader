import SwiftUI
import AppKit

struct DownloadRowView: View {
    var item: DownloadItem

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    statusIcon
                    Text(item.title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    formatBadge
                }

                if let artist = item.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                progressRow
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = item.thumbnailImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var progressRow: some View {
        switch item.status {
        case .downloading(let pct):
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: pct).progressViewStyle(.linear)
                Text("\(Int(pct * 100))%")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .converting:
            VStack(alignment: .leading, spacing: 2) {
                ProgressView().progressViewStyle(.linear)
                Text("Konvertiere…")
                    .font(.caption2).foregroundStyle(.orange)
            }
        case .failed(let msg):
            Text(msg)
                .font(.caption2).foregroundStyle(.red).lineLimit(2)
        case .queued:
            Text("Warteschlange")
                .font(.caption2).foregroundStyle(.secondary)
        case .done:
            Text("Fertig")
                .font(.caption2).foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .queued:
            Image(systemName: "clock").foregroundStyle(.secondary).font(.caption)
        case .downloading:
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.blue).font(.caption)
        case .converting:
            Image(systemName: "waveform").foregroundStyle(.orange).font(.caption)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
        }
    }

    @ViewBuilder
    private var formatBadge: some View {
        HStack(spacing: 3) {
            Text(item.format.rawValue)
            if let bitrate = item.bitrate { Text("·"); Text("\(bitrate)k") }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
