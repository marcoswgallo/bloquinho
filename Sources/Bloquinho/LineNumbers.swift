import AppKit

/// Números de linha à esquerda do texto. Fica dentro do editor (sobre o mesmo fundo) e cobre só a parte
/// visível. Só a primeira linha visual de cada parágrafo recebe número: linha comprida que quebra conta como uma.
final class LineNumberView: NSView {
    private unowned let textView: NSTextView
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let gap: CGFloat = 10  // espaço entre o número e o texto
    private var digits = 0
    private let baseInset: NSSize

    init(textView: NSTextView) {
        self.textView = textView
        baseInset = textView.textContainerInset
        super.init(frame: .zero)
        textView.addSubview(self)
        textView.postsFrameChangedNotifications = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(reposition), name: NSView.frameDidChangeNotification, object: textView)
        if let clip = textView.enclosingScrollView?.contentView {
            clip.postsBoundsChangedNotifications = true
            center.addObserver(self, selector: #selector(reposition), name: NSView.boundsDidChangeNotification, object: clip)
        }
        textChanged()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Número da linha onde fica a posição `index` (1 + quantos Enter vêm antes).
    static func lineNumber(at index: Int, in string: String) -> Int {
        string.utf16.prefix(index).lazy.filter { $0 == 10 }.count + 1
    }

    /// Chamar quando o texto muda: abre espaço para os dígitos na margem do texto e redesenha.
    /// (A margem do NSTextView é igual dos dois lados, então a da direita cresce junto.)
    func textChanged() {
        let total = Self.lineNumber(at: textView.string.utf16.count, in: textView.string)
        let newDigits = max(2, String(total).count)
        if newDigits != digits {
            digits = newDigits
            let column = ceil(("0" as NSString).size(withAttributes: [.font: font]).width) * CGFloat(digits) + gap
            textView.textContainerInset = NSSize(width: baseInset.width + column, height: baseInset.height)
        }
        reposition()
    }

    @objc private func reposition() {
        let visible = textView.visibleRect
        frame = NSRect(x: 0, y: visible.minY, width: textView.textContainerOrigin.x, height: visible.height)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let lm = textView.layoutManager, let container = textView.textContainer else { return }
        let text = textView.string as NSString
        let origin = textView.textContainerOrigin
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]

        /// Desenha `n` alinhado à direita, com a base do número na linha de base do texto (`baseline` no container).
        func draw(_ n: Int, baseline: CGFloat) {
            let s = String(n) as NSString
            let x = bounds.width - gap - s.size(withAttributes: attrs).width
            s.draw(at: NSPoint(x: x, y: origin.y + baseline - frame.minY - font.ascender), withAttributes: attrs)
        }

        let visible = NSRect(x: 0, y: frame.minY - origin.y, width: container.size.width, height: frame.height)
        let chars = lm.characterRange(forGlyphRange: lm.glyphRange(forBoundingRect: visible, in: container), actualGlyphRange: nil)
        var number = Self.lineNumber(at: chars.location, in: textView.string)
        var start = text.paragraphRange(for: NSRange(location: chars.location, length: 0)).location
        while start < text.length && start <= NSMaxRange(chars) {
            let glyph = lm.glyphIndexForCharacter(at: start)
            let line = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            draw(number, baseline: line.minY + lm.location(forGlyphAt: glyph).y)
            number += 1
            // Começo do próximo parágrafo. (Pedir o parágrafo do fim do texto devolveria o último de novo,
            // então avança a partir do começo deste, que sempre anda pelo menos um caractere.)
            start = NSMaxRange(text.paragraphRange(for: NSRange(location: start, length: 0)))
        }
        // Linha vazia no fim (nota vazia ou terminada em Enter).
        let extra = lm.extraLineFragmentRect
        if !extra.isEmpty {
            let typingFont = textView.typingAttributes[.font] as? NSFont ?? NoteFormat.defaultFont
            draw(number, baseline: extra.minY + lm.defaultBaselineOffset(for: typingFont))
        }
    }
}
