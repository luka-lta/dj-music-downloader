import Foundation
import Observation

@Observable
class DownloadSettings {
    var format: AudioFormat = .mp3
    var bitrate: Int = 320
    var outputPath: String = ""
    var outputPathChosen: Bool = false

    static let bitrateOptions = [64, 128, 192, 256, 320]
}
