import Foundation

final class SpotDlService {
    private let bin = BinaryManager.shared

    func download(item: DownloadItem) async {
        var args: [String] = [
            "download",
            item.url,
            "--output", item.outputPath,
            "--format", item.format.cliValue,
            "--ffmpeg", bin.ffmpegPath,
            "--print-errors",
        ]
        if let bitrate = item.bitrate {
            args += ["--bitrate", "\(bitrate)k"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin.spotdlPath)
        process.arguments = args
        process.environment = processEnv()

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try FileManager.default.createDirectory(atPath: item.outputPath, withIntermediateDirectories: true)
            try process.run()
        } catch {
            await set(item, status: .failed(error.localizedDescription))
            return
        }

        await set(item, status: .downloading(0))

        var trackTotal = 0
        var trackDone = 0

        do {
            for try await line in outPipe.fileHandleForReading.bytes.lines {
                if let total = parseTotal(line) {
                    trackTotal = total
                    await MainActor.run {
                        if item.title == "Lade..." { item.title = "Spotify Playlist (\(total) Tracks)" }
                    }
                }
                // spotdl prints: "Downloaded 'Title - Artist'"
                if let parsed = parseDownloadedTitle(line) {
                    await MainActor.run {
                        item.title = parsed.title
                        item.artist = parsed.artist
                    }
                }
                if line.contains("Downloaded") || line.contains("✓") || line.contains("Skipping") {
                    trackDone += 1
                    let pct = trackTotal > 0 ? Double(trackDone) / Double(trackTotal) : 0.5
                    await set(item, status: .downloading(min(pct, 1.0)))
                }
            }
        } catch {
            await set(item, status: .failed(error.localizedDescription))
            return
        }

        let code = await waitForExit(process)
        await set(item, status: code == 0 ? .done : .failed("Exit \(code)"))
    }

    private func parseTotal(_ line: String) -> Int? {
        let pattern = #/Found (\d+) songs/#
        if let match = line.firstMatch(of: pattern) { return Int(match.1) }
        return nil
    }

    private func parseDownloadedTitle(_ line: String) -> (title: String, artist: String?)? {
        // spotdl: "Downloaded 'Artist - Title'"
        let pattern = #/Downloaded "(.+)"/#
        if let match = line.firstMatch(of: pattern) {
            let full = String(match.1)
            let parts = full.components(separatedBy: " - ")
            if parts.count >= 2 {
                return (title: parts.dropFirst().joined(separator: " - "), artist: parts[0])
            }
            return (title: full, artist: nil)
        }
        return nil
    }

    @discardableResult
    private func waitForExit(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }

    private func processEnv() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        return env
    }

    @MainActor
    private func set(_ item: DownloadItem, status: DownloadStatus) {
        item.status = status
    }
}
