import Foundation
import Observation

@Observable
@MainActor
class DownloadQueue {
    var items: [DownloadItem] = []
    var settings = DownloadSettings()

    private let ytdlp = YtDlpService()
    private let spotdl = SpotDlService()

    func add(url: String, title: String = "Lade...", format: AudioFormat, bitrate: Int?) {
        let item = DownloadItem(url: url, title: title, format: format, bitrate: bitrate, outputPath: settings.outputPath)
        items.append(item)
        Task { await start(item) }
    }

    func addMany(_ entries: [(title: String, url: String)], format: AudioFormat, bitrate: Int?) {
        for entry in entries {
            let item = DownloadItem(url: entry.url, title: entry.title, format: format, bitrate: bitrate, outputPath: settings.outputPath)
            items.append(item)
            Task { await start(item) }
        }
    }

    func remove(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearDone() {
        items.removeAll { if case .done = $0.status { true } else { false } }
    }

    private func start(_ item: DownloadItem) async {
        switch item.source {
        case .youtube: await ytdlp.download(item: item)
        case .spotify: await spotdl.download(item: item)
        }
    }
}
