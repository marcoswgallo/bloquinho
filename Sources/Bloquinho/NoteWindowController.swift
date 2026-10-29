import AppKit

/// Uma aba = uma janela com o editor. As abas são as abas nativas de janela do macOS.
final class NoteWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSTextStorageDelegate {
    let id: String
    private(set) var fileURL: URL?
    private var changedSinceFileSave = false
    private var saveTimer: Timer?
    private weak var app: AppDelegate?
    let textView: NSTextView

    init(id: String, text: NSAttributedString?, fileURL: URL?, app: AppDelegate) {
        self.id = id
        self.fileURL = fileURL
        self.app = app

        let scroll = NSTextView.scrollableTextView()
        textView = scroll.documentView as! NSTextView

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "Bloquinho"
        window.isRestorable = false
        window.minSize = NSSize(width: 360, height: 240)
        super.init(window: window)
        window.delegate = self

        textView.isRichText = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.delegate = self
        textView.textStorage?.delegate = self
        if let text { textView.textStorage?.setAttributedString(text) }
        if textView.string.isEmpty { textView.typingAttributes = NoteFormat.defaultAttributes }

        let toolbar = makeToolbar()
        let separator = NSBox()
        separator.boxType = .separator
        let content = NSView()
        for v in [toolbar, separator, scroll] {
            v.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor),
            separator.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        window.initialFirstResponder = textView
        updateTitle()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Aba vazia que nunca veio de arquivo (pode ser reaproveitada ao abrir um arquivo).
    var isBlank: Bool { textView.string.isEmpty && fileURL == nil }

    func load(_ text: NSAttributedString, from url: URL) {
        textView.textStorage?.setAttributedString(text)
        if textView.string.isEmpty { textView.typingAttributes = NoteFormat.defaultAttributes }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        fileURL = url
        changedSinceFileSave = false
        updateTitle()
        saveNow()
    }

    func saveNow() {
        saveTimer?.invalidate()
        saveTimer = nil
        app?.store.saveText(textView.attributedString(), id: id)
        app?.saveState()
    }

    // MARK: Toolbar

    private func makeToolbar() -> NSView {
        let bold = NSButton(image: NSImage(systemSymbolName: "bold", accessibilityDescription: "Negrito")!,
                            target: self, action: #selector(toggleBold(_:)))
        bold.toolTip = "Negrito (⌘B)"
        let list = NSButton(image: NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Marcadores")!,
                            target: self, action: #selector(toggleBullets(_:)))
        list.toolTip = "Marcadores (⇧⌘L)"

        var views: [NSView] = [bold, list]
        for (i, entry) in NoteFormat.palette.enumerated() {
            // O "Padrão" aparece com a cor do texto do sistema, pra bater com o editor no modo escuro.
            let shown = i == 0 ? NSColor.labelColor : entry.color
            let button = NSButton(image: Self.swatch(shown), target: self, action: #selector(applyColor(_:)))
            button.isBordered = false
            button.tag = i
            button.toolTip = entry.name
            views.append(button)
        }
        let stack = NSStackView(views: views)
        stack.spacing = 8
        stack.setCustomSpacing(18, after: list)
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        return stack
    }

    private static func swatch(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            color.setFill()
            circle.fill()
            NSColor.separatorColor.setStroke()
            circle.stroke()
            return true
        }
    }

    // MARK: Ações (menus e botões)

    @objc func toggleBold(_ sender: Any?) { textView.toggleBoldFormatting() }
    @objc func toggleBullets(_ sender: Any?) { textView.toggleBullets() }

    @objc func applyColor(_ sender: NSButton) {
        textView.applyTextColor(NoteFormat.palette[sender.tag].color)
        window?.makeFirstResponder(textView)
    }

    @objc func saveNote(_ sender: Any?) {
        guard let url = fileURL else { return saveNoteAs(sender) }
        write(to: url)
    }

    @objc func saveNoteAs(_ sender: Any?) {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.rtf]
        let base = fileURL?.deletingPathExtension().lastPathComponent ?? firstLineTitle() ?? "Nota"
        panel.nameFieldStringValue = base.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-") + ".rtf"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.write(to: url)
        }
    }

    /// .rtf guarda a formatação; .txt (arquivo aberto do disco) é salvo como texto puro.
    private func write(to url: URL) {
        let text = textView.attributedString()
        do {
            if url.pathExtension.lowercased() == "rtf" {
                let data = try text.data(from: NSRange(location: 0, length: text.length),
                                         documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                try data.write(to: url, options: .atomic)
            } else {
                try text.string.write(to: url, atomically: true, encoding: .utf8)
            }
            fileURL = url
            changedSinceFileSave = false
            updateTitle()
            saveNow()
        } catch {
            if let window { NSAlert(error: error).beginSheetModal(for: window) }
        }
    }

    // MARK: Título

    private func firstLineTitle() -> String? {
        let line = textView.string.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && $0 != NoteFormat.bullet.trimmingCharacters(in: .whitespaces) }
        guard var line else { return nil }
        if line.hasPrefix(NoteFormat.bullet) { line.removeFirst(NoteFormat.bullet.count) }
        return String(line.prefix(40))
    }

    private func updateTitle() {
        window?.title = fileURL?.lastPathComponent ?? firstLineTitle() ?? "Nova nota"
        window?.isDocumentEdited = fileURL != nil && changedSinceFileSave
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        changedSinceFileSave = true
        updateTitle()
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in self?.saveNow() }
    }

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        return textView.handleNewlineInBulletList()
    }

    /// O "Colar" do menu de contexto também cola sem a formatação de fora (igual ao ⌘V).
    func textView(_ view: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
        menu.items.first { $0.action == #selector(NSText.paste(_:)) }?.action = #selector(NSTextView.pasteAsPlainText(_:))
        return menu
    }

    // MARK: NSTextStorageDelegate

    /// Todo texto que entra (colado, arrastado, aberto de arquivo) fica só com negrito e cores da paleta.
    func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        textStorage.enumerateAttributes(in: editedRange) { attrs, range, _ in
            textStorage.setAttributes(NoteFormat.clean(attrs), range: range)
        }
    }

    // MARK: NSWindowDelegate

    /// O botão vermelho fecha o app guardando tudo (as abas voltam ao reabrir).
    /// Fechar a aba (⌘W ou o x da aba) apaga a nota; pede confirmação se houver texto que não está salvo em arquivo.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.isClickingCloseButton {
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return false
        }
        let hasText = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasText, fileURL == nil || changedSinceFileSave else { return true }
        let alert = NSAlert()
        alert.messageText = "Fechar esta aba?"
        alert.informativeText = fileURL == nil
            ? "O texto desta aba não foi salvo em arquivo e será apagado."
            : "As alterações desde o último salvamento serão perdidas."
        alert.addButton(withTitle: "Cancelar")
        alert.addButton(withTitle: "Apagar").hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        saveTimer?.invalidate()
        app?.noteClosed(self)
    }
}

extension NSWindow {
    /// O evento atual é um clique no botão vermelho desta janela? (⌘W e o x da aba também passam
    /// pelo botão por dentro, então só a posição do clique diferencia.)
    var isClickingCloseButton: Bool {
        guard let event = NSApp.currentEvent, event.window === self,
              event.type == .leftMouseDown || event.type == .leftMouseUp,
              let button = standardWindowButton(.closeButton) else { return false }
        return button.bounds.contains(button.convert(event.locationInWindow, from: nil))
    }
}
