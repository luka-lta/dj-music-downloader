import Foundation
import Observation
import AppKit

enum DownloadStatus: Equatable {
    case queued
    case downloading(Double)
    case converting
    case done
    case failed(String)

    static func == (lhs: DownloadStatus, rhs: DownloadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.queued, .queued), (.converting, .converting), (.done, .done): return true
        case (.downloading(let a), .downloading(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

enum DownloadSource {
    case youtube, spotify

    static func detect(from url: String) -> DownloadSource {
        url.contains("spotify.com") ? .spotify : .youtube
    }
}

enum AudioFormat: String, CaseIterable, Identifiable {
    case mp3 = "MP3"
    case aac = "AAC"
    case ogg = "OGG"
    case flac = "FLAC"
    case wav = "WAV"

    var id: String { rawValue }
    var isLossless: Bool { self == .flac || self == .wav }
    var cliValue: String { rawValue.lowercased() }
}

@Observable
class DownloadItem: Identifiable {
    let id = UUID()
    let url: String
    var title: String
    var artist: String?
    var thumbnailImage: NSImage?
    var status: DownloadStatus = .queued
    let source: DownloadSource
    let format: AudioFormat
    let bitrate: Int?
    let outputPath: String

    init(url: String, title: String = "Lade...", format: AudioFormat, bitrate: Int?, outputPath: String) {
        self.url = url
        self.title = title
        self.source = DownloadSource.detect(from: url)
        self.format = format
        self.bitrate = bitrate
        self.outputPath = outputPath
    }
}
