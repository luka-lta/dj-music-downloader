import Foundation

enum BinaryManagerError: LocalizedError {
    case notFound(String)
    case setupFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let n): return "'\(n)' nicht im App-Bundle gefunden. Bitte Binary zu Resources hinzufügen."
        case .setupFailed(let m): return "Setup fehlgeschlagen: \(m)"
        }
    }
}

final class BinaryManager {
    static let shared = BinaryManager()

    private let binDir: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DJDownloader/bin")

    var ytDlpPath: String { binDir.appendingPathComponent("yt-dlp").path }
    var ffmpegPath: String { binDir.appendingPathComponent("ffmpeg").path }
    var spotdlPath: String { binDir.appendingPathComponent("spotdl").path }

    var isReady: Bool {
        let fm = FileManager.default
        return fm.isExecutableFile(atPath: ytDlpPath)
            && fm.isExecutableFile(atPath: ffmpegPath)
            && fm.isExecutableFile(atPath: spotdlPath)
    }

    func setup() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: binDir, withIntermediateDirectories: true)

        let binaries: [(name: String, prefixes: [String])] = [
            ("yt-dlp",  ["yt-dlp", "yt-dlp_macos"]),
            ("ffmpeg",  ["ffmpeg"]),
            ("spotdl",  ["spotdl", "spotdl-macos"]),
        ]

        for (destName, candidates) in binaries {
            let src = candidates.lazy
                .compactMap { Bundle.main.url(forResource: $0, withExtension: nil) }
                .first
            guard let src else {
                throw BinaryManagerError.notFound(destName)
            }
            let dest = binDir.appendingPathComponent(destName)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.copyItem(at: src, to: dest)
            try fm.setAttributes([.posixPermissions: 0o755 as NSNumber], ofItemAtPath: dest.path)
            removeQuarantine(dest.path)
        }
    }

    private func removeQuarantine(_ path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-d", "com.apple.quarantine", path]
        try? p.run()
        p.waitUntilExit()
    }
}
