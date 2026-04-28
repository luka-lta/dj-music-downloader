import Foundation
import AppKit

final class YtDlpService {
    private let bin = BinaryManager.shared

    func download(item: DownloadItem) async {
        var args: [String] = [
            "--extract-audio",
            "--audio-format", item.format.cliValue,
            "--ffmpeg-location", bin.ffmpegPath,
            "--embed-thumbnail",
            "--add-metadata",
            "--output", "\(item.outputPath)/%(title)s.%(ext)s",
            "--newline",
            "--no-warnings",
            "--print", "before_dl:METADATA\t%(title)s\t%(uploader)s\t%(thumbnail)s",
        ]
        if let bitrate = item.bitrate {
            args += ["--audio-quality", "\(bitrate)k"]
        }
        args.append(item.url)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin.ytDlpPath)
        process.arguments = args
        process.environment = processEnv()

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        do {
            try FileManager.default.createDirectory(atPath: item.outputPath, withIntermediateDirectories: true)
            try process.run()
        } catch {
            await set(item, status: .failed(error.localizedDescription))
            return
        }

        await set(item, status: .downloading(0))

        // Blocking line-by-line read on background thread — EOF signals process done
        let exitCode: Int32 = await Task.detached(priority: .utility) { [self] in
            let handle = outPipe.fileHandleForReading
            var buffer = ""

            while true {
                guard let data = try? handle.read(upToCount: 4096), !data.isEmpty else { break }
                buffer += String(data: data, encoding: .utf8) ?? ""
                var lines = buffer.components(separatedBy: "\n")
                buffer = lines.removeLast() // keep incomplete trailing line
                for line in lines {
                    let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { continue }
                    await self.handleLine(t, item: item)
                }
            }

            process.waitUntilExit()
            return process.terminationStatus
        }.value

        await set(item, status: exitCode == 0 ? .done : .failed("Exit \(exitCode)"))
    }

    private func handleLine(_ line: String, item: DownloadItem) async {
        if line.hasPrefix("METADATA\t") {
            let parts = line.components(separatedBy: "\t")
            if parts.count > 1, !parts[1].isEmpty {
                await MainActor.run { item.title = parts[1] }
            }
            if parts.count > 2, !parts[2].isEmpty {
                await MainActor.run { item.artist = parts[2] }
            }
            if parts.count > 3, !parts[3].isEmpty {
                Task { await self.loadThumbnail(parts[3], into: item) }
            }
        } else if line.contains("[ExtractAudio]") || line.contains("Merging") {
            await set(item, status: .converting)
        } else if let pct = parsePercent(line) {
            await set(item, status: .downloading(pct))
        } else if let title = parseTitle(line) {
            await MainActor.run { if item.title == "Lade..." { item.title = title } }
        }
    }

    private func loadThumbnail(_ urlStr: String, into item: DownloadItem) async {
        guard let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return }
        await MainActor.run { item.thumbnailImage = image }
    }

    func fetchPlaylistItems(url: String) async throws -> [(title: String, url: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin.ytDlpPath)
        process.arguments = ["--flat-playlist", "--print", "%(title)s\t%(webpage_url)s", "--no-warnings", url]
        process.environment = processEnv()

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        try process.run()

        let output: String = await Task.detached(priority: .utility) {
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        }.value

        return output
            .components(separatedBy: "\n")
            .compactMap { line -> (title: String, url: String)? in
                let parts = line.components(separatedBy: "\t")
                guard parts.count >= 2, !parts[1].isEmpty else { return nil }
                return (title: parts[0], url: parts[1])
            }
    }

    private func parseTitle(_ line: String) -> String? {
        guard line.contains("Destination:") else { return nil }
        let parts = line.components(separatedBy: "Destination:")
        guard parts.count > 1 else { return nil }
        let filename = parts[1].trimmingCharacters(in: .whitespaces)
        return URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }

    private func parsePercent(_ line: String) -> Double? {
        guard line.contains("[download]") else { return nil }
        let tokens = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for token in tokens where token.hasSuffix("%") {
            if let val = Double(token.dropLast()) { return val / 100.0 }
        }
        return nil
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
