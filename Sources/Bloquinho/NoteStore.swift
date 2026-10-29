import AppKit

/// Estado das abas: ordem, aba selecionada e arquivo de origem de cada nota (se houver).
struct NoteState: Codable {
    var order: [String] = []
    var selected: String?
    var files: [String: String] = [:]
}

/// Guarda as notas em ~/Library/Application Support/Bloquinho (uma .rtf por aba + state.json).
final class NoteStore {
    let dir: URL
    private var notesDir: URL { dir.appendingPathComponent("notes") }
    private var stateURL: URL { dir.appendingPathComponent("state.json") }

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bloquinho")
        try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
    }

    func loadState() -> NoteState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(NoteState.self, from: data) else { return NoteState() }
        return state
    }

    func saveState(_ state: NoteState) {
        try? JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
    }

    func loadText(id: String) -> NSAttributedString? {
        guard let data = try? Data(contentsOf: noteURL(id)) else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }

    func saveText(_ text: NSAttributedString, id: String) {
        let data = text.rtf(from: NSRange(location: 0, length: text.length), documentAttributes: [:])
        try? data?.write(to: noteURL(id), options: .atomic)
    }

    func delete(id: String) {
        try? FileManager.default.removeItem(at: noteURL(id))
    }

    private func noteURL(_ id: String) -> URL { notesDir.appendingPathComponent("\(id).rtf") }
}
