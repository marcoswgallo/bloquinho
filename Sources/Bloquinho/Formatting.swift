import AppKit

enum NoteFormat {
    static let defaultFont = NSFont.systemFont(ofSize: 14)
    static let defaultAttributes: [NSAttributedString.Key: Any] = [.font: defaultFont, .foregroundColor: NSColor.black]
    static let bullet = "• "

    /// Preto é o "padrão": no modo escuro o editor mostra ele em branco automaticamente.
    static let palette: [(name: String, color: NSColor)] = [
        ("Padrão", .black),
        ("Vermelho", NSColor(srgbRed: 0.85, green: 0.16, blue: 0.16, alpha: 1)),
        ("Laranja", NSColor(srgbRed: 0.93, green: 0.49, blue: 0.05, alpha: 1)),
        ("Verde", NSColor(srgbRed: 0.13, green: 0.58, blue: 0.25, alpha: 1)),
        ("Azul", NSColor(srgbRed: 0.10, green: 0.40, blue: 0.85, alpha: 1)),
        ("Roxo", NSColor(srgbRed: 0.55, green: 0.22, blue: 0.78, alpha: 1)),
    ]

    /// Reduz os atributos ao que o Bloquinho usa: fonte padrão (com ou sem negrito) e uma cor da paleta.
    /// Fundo, outras fontes e outras cores (de texto colado de fora) voltam ao padrão.
    static func clean(_ attrs: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let fm = NSFontManager.shared
        let bold = (attrs[.font] as? NSFont).map { fm.traits(of: $0).contains(.boldFontMask) } ?? false
        let font = bold ? fm.convert(defaultFont, toHaveTrait: .boldFontMask) : defaultFont
        let color = (attrs[.foregroundColor] as? NSColor).flatMap(paletteColor) ?? .black
        return [.font: font, .foregroundColor: color]
    }

    /// A cor da paleta igual a `color` (comparando em sRGB, pois a cor muda de espaço ao passar pelo RTF).
    private static func paletteColor(_ color: NSColor) -> NSColor? {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        return palette.map(\.color).first { entry in
            guard let p = entry.usingColorSpace(.sRGB) else { return false }
            return abs(p.redComponent - c.redComponent) < 0.02 && abs(p.greenComponent - c.greenComponent) < 0.02
                && abs(p.blueComponent - c.blueComponent) < 0.02
        }
    }
}

extension NSTextView {
    func toggleBoldFormatting() {
        let fm = NSFontManager.shared
        let range = selectedRange()
        func isBold(_ font: NSFont) -> Bool { fm.traits(of: font).contains(.boldFontMask) }
        func toggled(_ font: NSFont, bold: Bool) -> NSFont {
            bold ? fm.convert(font, toHaveTrait: .boldFontMask) : fm.convert(font, toNotHaveTrait: .boldFontMask)
        }

        if range.length == 0 {
            let font = typingAttributes[.font] as? NSFont ?? NoteFormat.defaultFont
            typingAttributes[.font] = toggled(font, bold: !isBold(font))
            return
        }
        guard let storage = textStorage, shouldChangeText(in: range, replacementString: nil) else { return }
        var allBold = true
        storage.enumerateAttribute(.font, in: range) { value, _, _ in
            if !isBold(value as? NSFont ?? NoteFormat.defaultFont) { allBold = false }
        }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            storage.addAttribute(.font, value: toggled(value as? NSFont ?? NoteFormat.defaultFont, bold: !allBold), range: sub)
        }
        storage.endEditing()
        didChangeText()
    }

    func applyTextColor(_ color: NSColor) {
        let range = selectedRange()
        if range.length == 0 {
            typingAttributes[.foregroundColor] = color
            return
        }
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage?.addAttribute(.foregroundColor, value: color, range: range)
        didChangeText()
    }

    /// Põe ou tira "• " no começo de cada linha selecionada (num só passo de desfazer).
    func toggleBullets() {
        guard let storage = textStorage else { return }
        let ns = string as NSString
        let bullet = NoteFormat.bullet
        let bulletLength = (bullet as NSString).length
        let paraRange = ns.paragraphRange(for: selectedRange())

        var starts: [Int] = []
        ns.enumerateSubstrings(in: paraRange, options: [.byParagraphs, .substringNotRequired]) { _, r, _, _ in
            starts.append(r.location)
        }
        if starts.isEmpty { starts = [paraRange.location] }  // linha vazia no fim do texto

        func hasBullet(_ loc: Int) -> Bool {
            loc + bulletLength <= ns.length && ns.substring(with: NSRange(location: loc, length: bulletLength)) == bullet
        }
        let removing = starts.allSatisfy(hasBullet)

        let block = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: paraRange))
        for start in starts.reversed() {
            let local = start - paraRange.location
            if removing {
                block.deleteCharacters(in: NSRange(location: local, length: bulletLength))
            } else if !hasBullet(start) {
                let attrs = local < block.length ? block.attributes(at: local, effectiveRange: nil) : typingAttributes
                block.insert(NSAttributedString(string: bullet, attributes: attrs), at: local)
            }
        }

        guard shouldChangeText(in: paraRange, replacementString: block.string) else { return }
        storage.replaceCharacters(in: paraRange, with: block)
        didChangeText()
        let end = paraRange.location + block.length - (block.string.hasSuffix("\n") ? 1 : 0)
        setSelectedRange(NSRange(location: end, length: 0))
    }

    /// Enter numa linha com marcador continua a lista; Enter num marcador vazio encerra a lista.
    /// Retorna true se tratou o Enter.
    func handleNewlineInBulletList() -> Bool {
        let sel = selectedRange()
        guard sel.length == 0 else { return false }
        let ns = string as NSString
        let bullet = NoteFormat.bullet
        let bulletLength = (bullet as NSString).length
        let para = ns.paragraphRange(for: NSRange(location: sel.location, length: 0))
        let line = ns.substring(with: para).trimmingCharacters(in: .newlines)
        guard line.hasPrefix(bullet), sel.location >= para.location + bulletLength else { return false }

        if line == bullet {
            let r = NSRange(location: para.location, length: bulletLength)
            if shouldChangeText(in: r, replacementString: "") {
                textStorage?.replaceCharacters(in: r, with: "")
                didChangeText()
            }
            return true
        }
        insertText("\n" + bullet, replacementRange: sel)
        return true
    }
}
