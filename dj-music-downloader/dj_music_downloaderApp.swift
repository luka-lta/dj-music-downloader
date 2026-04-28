import SwiftUI

@main
struct dj_music_downloaderApp: App {
    @State private var isReady = false
    @State private var setupError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if isReady {
                    ContentView()
                } else if let err = setupError {
                    SetupErrorView(message: err)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Initialisiere…").foregroundStyle(.secondary)
                    }
                    .padding(40)
                    .task { await setup() }
                }
            }
        }
        .windowResizability(.contentMinSize)
    }

    private func setup() async {
        do {
            try BinaryManager.shared.setup()
            await MainActor.run { isReady = true }
        } catch {
            await MainActor.run { setupError = error.localizedDescription }
        }
    }
}

struct SetupErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Setup fehlgeschlagen").font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("yt-dlp, ffmpeg und spotdl müssen im App-Bundle unter Resources liegen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 420)
    }
}
