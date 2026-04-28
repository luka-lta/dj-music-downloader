import SwiftUI

struct ContentView: View {
    @State private var queue = DownloadQueue()
    @State private var showAdd = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if queue.items.isEmpty {
                    ContentUnavailableView(
                        "Keine Downloads",
                        systemImage: "music.note.list",
                        description: Text("URL einfügen um Musik herunterzuladen")
                    )
                } else {
                    List {
                        ForEach(queue.items) { item in
                            DownloadRowView(item: item)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { queue.remove(item) } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("DJ Downloader")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Label("Hinzufügen", systemImage: "plus")
                    }
                }
                ToolbarItemGroup(placement: .navigation) {
                    Button { showSettings = true } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                    if queue.items.contains(where: { if case .done = $0.status { true } else { false } }) {
                        Button { queue.clearDone() } label: {
                            Label("Fertige löschen", systemImage: "checkmark.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddDownloadSheet(queue: queue)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView(settings: queue.settings) }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            if !queue.settings.outputPathChosen {
                pickFolderOnFirstLaunch()
            }
        }
    }

    private func pickFolderOnFirstLaunch() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Wo sollen deine DJ-Downloads gespeichert werden?"
        panel.prompt = "Auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            queue.settings.outputPath = url.path
            queue.settings.outputPathChosen = true
        }
    }
}

#Preview {
    ContentView()
}
