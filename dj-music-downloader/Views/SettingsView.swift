import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: DownloadSettings

    var body: some View {
        Form {
            Section("Standard-Format") {
                Picker("Format", selection: $settings.format) {
                    ForEach(AudioFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                if !settings.format.isLossless {
                    Picker("Bitrate", selection: $settings.bitrate) {
                        ForEach(DownloadSettings.bitrateOptions, id: \.self) { b in
                            Text("\(b) kbps").tag(b)
                        }
                    }
                }
            }
            Section("Speicherort") {
                HStack {
                    if settings.outputPath.isEmpty {
                        Text("Noch nicht gewählt")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(settings.outputPath)
                            .truncationMode(.head)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(settings.outputPath.isEmpty ? "Wählen" : "Ändern") {
                        chooseFolder()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .navigationTitle("Einstellungen")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Ordner für DJ-Downloads wählen"
        panel.prompt = "Auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            settings.outputPath = url.path
            settings.outputPathChosen = true
        }
    }
}
