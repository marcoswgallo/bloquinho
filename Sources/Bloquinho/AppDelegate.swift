import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NoteStore()
    private var controllers: [NoteWindowController] = []
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()

        let state = store.loadState()
        for id in state.order {
            guard let text = store.loadText(id: id) else { continue }
            addTab(NoteWindowController(id: id, text: text, fileURL: state.files[id].map { URL(fileURLWithPath: $0) }, app: self))
        }
        if controllers.isEmpty { addTab(newNote()) }

        let selected = controllers.first { $0.id == state.selected } ?? controllers.last!
        selected.window?.makeKeyAndOrderFront(nil)
        if let window = selected.window, window.tabGroup?.isTabBarVisible == false { window.toggleTabBar(nil) }
        NSApp.activate()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        controllers.forEach { $0.saveNow() }
        saveState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: Abas

    private func newNote() -> NoteWindowController {
        NoteWindowController(id: UUID().uuidString, text: nil, fileURL: nil, app: self)
    }

    /// Adiciona a aba depois de `after` (ou no fim do grupo).
    private func addTab(_ controller: NoteWindowController, after: NSWindow? = nil) {
        guard let window = controller.window else { return }
        if let anchor = after ?? controllers.last?.window {
            anchor.addTabbedWindow(window, ordered: .above)
        } else {
            window.setFrameAutosaveName("BloquinhoJanela")
            window.makeKeyAndOrderFront(nil)
        }
        controllers.append(controller)
    }

    private var currentController: NoteWindowController? {
        controllers.first { $0.window === NSApp.keyWindow }
    }

    func noteClosed(_ controller: NoteWindowController) {
        controllers.removeAll { $0 === controller }
        guard !isTerminating else { return }
        store.delete(id: controller.id)
        saveState()
    }

    func saveState() {
        guard !isTerminating || !controllers.isEmpty else { return }
        let group = controllers.first?.window?.tabbedWindows ?? controllers.compactMap(\.window)
        var order = group.compactMap { w in controllers.first { $0.window === w }?.id }
        for c in controllers where !order.contains(c.id) { order.append(c.id) }
        let selectedWindow = controllers.first?.window?.tabGroup?.selectedWindow
        var state = NoteState(order: order, selected: controllers.first { $0.window === selectedWindow }?.id)
        for c in controllers { state.files[c.id] = c.fileURL?.path }
        store.saveState(state)
    }

    // MARK: Ações

    @objc func newWindowForTab(_ sender: Any?) {
        let controller = newNote()
        addTab(controller, after: NSApp.keyWindow)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.saveNow()
    }

    @objc func openNote(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .rtf]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        open(panel.urls)
    }

    /// Abre cada arquivo numa aba nova (ou na aba atual, se ela estiver vazia).
    func open(_ urls: [URL]) {
        for url in urls {
            guard let text = Self.read(url) else {
                NSAlert(error: CocoaError(.fileReadUnknown, userInfo: [NSFilePathErrorKey: url.path])).runModal()
                continue
            }
            if let current = currentController, current.isBlank {
                current.load(text, from: url)
            } else {
                let controller = NoteWindowController(id: UUID().uuidString, text: nil, fileURL: nil, app: self)
                addTab(controller, after: NSApp.keyWindow)
                controller.load(text, from: url)
                controller.window?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private static func read(_ url: URL) -> NSAttributedString? {
        if url.pathExtension.lowercased() == "rtf" {
            return try? NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf],
                                           documentAttributes: nil)
        }
        // .txt do Notepad do Windows costuma vir em UTF-8 ou Windows-1252.
        guard let s = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .windowsCP1252))
        else { return nil }
        return NSAttributedString(string: s, attributes: NoteFormat.defaultAttributes)
    }
}
