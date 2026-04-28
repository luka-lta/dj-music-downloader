import SwiftUI

struct AddDownloadSheet: View {
    @Environment(\.dismiss) private var dismiss
    var queue: DownloadQueue

    @State private var urlText = ""
    @State private var format: AudioFormat = .mp3
    @State private var bitrate = 320
    @State private var playlistItems: [(title: String, url: String)] = []
    @State private var selectedURLs: Set<String> = []
    @State private var isLoadingPlaylist = false
    @State private var errorMessage: String?

    private var isPlaylist: Bool {
        urlText.contains("playlist") || urlText.contains("list=") ||
        (urlText.contains("spotify.com") && urlText.contains("/playlist/"))
    }

    private var isSpotify: Bool { urlText.contains("spotify.com") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Download hinzufügen")
                .font(.headline)

            TextField("YouTube, YT Music oder Spotify URL", text: $urlText)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                Picker("Format", selection: $format) {
                    ForEach(AudioFormat.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                if !format.isLossless {
                    Picker("Bitrate", selection: $bitrate) {
                        ForEach(DownloadSettings.bitrateOptions, id: \.self) { b in
                            Text("\(b) kbps").tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 110)
                }
            }

            if !playlistItems.isEmpty {
                Divider()
                HStack {
                    Text("Playlist — \(playlistItems.count) Tracks")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("Alle") { selectedURLs = Set(playlistItems.map { $0.url }) }
                        .buttonStyle(.plain).foregroundStyle(.blue)
                    Text("/").foregroundStyle(.secondary)
                    Button("Keine") { selectedURLs = [] }
                        .buttonStyle(.plain).foregroundStyle(.blue)
                }
                List(playlistItems, id: \.url) { item in
                    HStack {
                        Image(systemName: selectedURLs.contains(item.url) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedURLs.contains(item.url) ? .blue : .secondary)
                        Text(item.title).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedURLs.contains(item.url) { selectedURLs.remove(item.url) }
                        else { selectedURLs.insert(item.url) }
                    }
                }
                .frame(height: 220)
                .border(Color.secondary.opacity(0.25), width: 1)
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isPlaylist && playlistItems.isEmpty && !isSpotify {
                    if isLoadingPlaylist { ProgressView().controlSize(.small) }
                    Button("Playlist laden") { loadPlaylist() }
                        .disabled(urlText.isEmpty || isLoadingPlaylist)
                } else {
                    let count = playlistItems.isEmpty ? nil : selectedURLs.count
                    Button(count.map { "Herunterladen (\($0))" } ?? "Herunterladen") {
                        startDownload()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(urlText.isEmpty || (!playlistItems.isEmpty && selectedURLs.isEmpty))
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }

    private func loadPlaylist() {
        isLoadingPlaylist = true
        errorMessage = nil
        Task {
            do {
                let items = try await YtDlpService().fetchPlaylistItems(url: urlText)
                await MainActor.run {
                    playlistItems = items
                    selectedURLs = Set(items.map { $0.url })
                    isLoadingPlaylist = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingPlaylist = false
                }
            }
        }
    }

    private func startDownload() {
        let currentBitrate = format.isLossless ? nil : bitrate
        if !playlistItems.isEmpty {
            let toDownload = playlistItems.filter { selectedURLs.contains($0.url) }
            queue.addMany(toDownload, format: format, bitrate: currentBitrate)
        } else {
            queue.add(url: urlText, format: format, bitrate: currentBitrate)
        }
        dismiss()
    }
}
