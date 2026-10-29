import AppKit
import UniformTypeIdentifiers

/// Uma aba = uma janela com o editor. As abas são as abas nativas de janela do macOS.
final class NoteWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSTextStorageDelegate {
    let id: String
    private(set) var fileURL: URL?
    private var changedSinceFileSave = false
    private var saveTimer: Timer?
    private weak var app: AppDelegate?
    let textView: NoteTextView
    private var lineNumbers: LineNumberView!
    private let status = NSTextField(labelWithString: "")
    private var docCounts = (chars: 0, words: 0)
    private var countTimer: Timer?
    private weak var savePanel: NSSavePanel?
    private var fittingWidth = false

    init(id: String, text: NSAttributedString?, fileURL: URL?, app: AppDelegate) {
        self.id = id
        self.fileURL = fileURL
        self.app = app

        // TextKit 1: os números de linha (LineNumbers.swift) medem as linhas pelo layoutManager,
        // então o editor precisa desenhar com o mesmo motor.
        textView = NoteTextView(usingTextLayoutManager: false)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.allowsMagnification = true  // zoom (⌘+ ⌘− e pinça no trackpad)
        scroll.minMagnification = 0.5
        scroll.maxMagnification = 3
        scroll.documentView = textView

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "Bloquinho"
        window.isRestorable = false
        window.minSize = NSSize(width: 360, height: 240)
        super.init(window: window)
        window.delegate = self
        // O botão vermelho fecha o app guardando tudo (as abas voltam ao reabrir).
        window.standardWindowButton(.closeButton)?.target = NSApp
        window.standardWindowButton(.closeButton)?.action = #selector(NSApplication.terminate(_:))

        textView.isRichText = true
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.delegate = self
        textView.textStorage?.delegate = self
        textView.onDropFiles = { [weak app] urls in app?.open(urls) }
        if let text { textView.textStorage?.setAttributedString(text) }
        if textView.string.isEmpty { textView.typingAttributes = NoteFormat.defaultAttributes }

        let toolbar = makeToolbar()
        let separator = NSBox()
        separator.boxType = .separator
        let bottomSeparator = NSBox()
        bottomSeparator.boxType = .separator
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        let content = NSView()
        for v in [toolbar, separator, scroll, bottomSeparator, status] {
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
            scroll.bottomAnchor.constraint(equalTo: bottomSeparator.topAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            status.topAnchor.constraint(equalTo: bottomSeparator.bottomAnchor, constant: 4),
            status.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            status.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4),
        ])
        window.contentView = content
        window.initialFirstResponder = textView
        lineNumbers = LineNumberView(textView: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(zoomChanged),
                                               name: NSScrollView.didEndLiveMagnifyNotification, object: scroll)
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.contentView.postsFrameChangedNotifications = true
        for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(fitTextWidth), name: name, object: scroll.contentView)
        }
        updateTitle()
        recount()
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
        lineNumbers.textChanged()
        recount()
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

    /// ⌘W. Não usa performClose, que "aperta" o botão vermelho e fecharia o app.
    @objc func closeTab(_ sender: Any?) {
        guard let window, windowShouldClose(window) else { return }
        window.close()
    }

    @objc func saveNote(_ sender: Any?) {
        guard let url = fileURL else { return saveNoteAs(sender) }
        write(to: url)
    }

    @objc func saveNoteAs(_ sender: Any?) {
        guard let window else { return }
        let panel = NSSavePanel()
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: Self.saveFormats.map(\.title))
        popup.selectItem(at: fileURL?.pathExtension.lowercased() == "txt" ? 1 : 0)
        popup.target = self
        popup.action = #selector(saveFormatChanged(_:))
        let accessory = NSStackView(views: [NSTextField(labelWithString: "Formato:"), popup])
        accessory.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        panel.accessoryView = accessory
        let format = Self.saveFormats[popup.indexOfSelectedItem]
        panel.allowedContentTypes = [format.type]
        let base = fileURL?.deletingPathExtension().lastPathComponent ?? firstLineTitle() ?? "Nota"
        panel.nameFieldStringValue = base.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-") + "." + format.type.preferredFilenameExtension!
        savePanel = panel
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.write(to: url)
        }
    }

    /// RTF guarda a formatação; .txt é texto puro.
    private static let saveFormats: [(title: String, type: UTType)] = [
        ("RTF (com formatação)", .rtf), ("Texto puro (.txt), sem formatação", .plainText),
    ]

    @objc private func saveFormatChanged(_ popup: NSPopUpButton) {
        guard let panel = savePanel else { return }
        let type = Self.saveFormats[popup.indexOfSelectedItem].type
        panel.allowedContentTypes = [type]
        let name = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = name + "." + type.preferredFilenameExtension!
    }

    /// .rtf guarda a formatação; qualquer outra extensão (.txt) é salva como texto puro.
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

    // MARK: Zoom

    @objc func zoomIn(_ sender: Any?) { setZoom(zoom + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom(zoom - 0.1) }
    @objc func zoomReset(_ sender: Any?) { setZoom(1) }

    private var zoom: CGFloat { textView.enclosingScrollView?.magnification ?? 1 }

    private func setZoom(_ value: CGFloat) {
        textView.enclosingScrollView?.magnification = (value * 10).rounded() / 10
        zoomChanged()
    }

    @objc private func zoomChanged() { updateStatus() }

    /// Com zoom, a área visível muda de largura sem a janela mudar; o editor acompanha essa largura
    /// para o texto continuar quebrando dentro da tela. Mudar a largura faz a área visível avisar de novo,
    /// e com zoom quebrado (110%) o AppKit arredonda a largura para o pixel; daí a tolerância e a trava.
    @objc private func fitTextWidth() {
        guard !fittingWidth, let width = textView.enclosingScrollView?.contentView.bounds.width,
              abs(textView.frame.width - width) > 0.5 else { return }
        fittingWidth = true
        defer { fittingWidth = false }
        textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
    }

    // MARK: Contagem (rodapé)

    /// Caracteres (sem contar as quebras de linha) e palavras.
    static func counts(_ s: String) -> (chars: Int, words: Int) {
        var words = 0
        s.enumerateSubstrings(in: s.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in words += 1 }
        return (s.lazy.filter { !$0.isNewline }.count, words)
    }

    private func recount() {
        countTimer?.invalidate()
        countTimer = nil
        docCounts = Self.counts(textView.string)
        updateStatus()
    }

    /// "1.234 caracteres · 210 palavras"; com texto selecionado, conta só a seleção.
    private func updateStatus() {
        func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n.formatted()) \(n == 1 ? one : many)" }
        let selection = textView.selectedRange()
        let c = selection.length > 0 ? Self.counts((textView.string as NSString).substring(with: selection)) : docCounts
        var parts = [plural(c.chars, "caractere", "caracteres"), plural(c.words, "palavra", "palavras")]
        if selection.length > 0 { parts[0] = "Seleção: " + parts[0] }
        if abs(zoom - 1) > 0.01 { parts.append("Zoom \(Int((zoom * 100).rounded()))%") }
        status.stringValue = parts.joined(separator: " · ")
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
        lineNumbers.textChanged()
        // Recontar a nota inteira a cada tecla pesaria em notas grandes; espera uma pausa curta.
        countTimer?.invalidate()
        countTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in self?.recount() }
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in self?.saveNow() }
    }

    func textViewDidChangeSelection(_ notification: Notification) { updateStatus() }

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

    /// Fechar a aba (⌘W ou o x da aba) apaga a nota; pede confirmação se houver texto que não está salvo em arquivo.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
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

/// O editor. Soltar arquivos .txt/.rtf nele abre cada um numa aba (em vez de colar o caminho no texto).
final class NoteTextView: NSTextView {
    var onDropFiles: (([URL]) -> Void)?

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.plainText.identifier, UTType.rtf.identifier],
        ]
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
        guard !urls.isEmpty, let onDropFiles else { return super.performDragOperation(sender) }
        onDropFiles(urls)
        return true
    }
}
