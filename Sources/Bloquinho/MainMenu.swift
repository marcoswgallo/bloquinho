import AppKit

enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()

        main.addItem(submenu("Bloquinho", [
            item("Sobre o Bloquinho", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Ocultar Bloquinho", #selector(NSApplication.hide(_:)), "h"),
            item("Sair do Bloquinho", #selector(NSApplication.terminate(_:)), "q"),
        ]))

        main.addItem(submenu("Arquivo", [
            item("Nova aba", #selector(NSResponder.newWindowForTab(_:)), "t"),
            item("Abrir…", #selector(AppDelegate.openNote(_:)), "o"),
            .separator(),
            item("Fechar aba", #selector(NoteWindowController.closeTab(_:)), "w"),
            item("Salvar", #selector(NoteWindowController.saveNote(_:)), "s"),
            item("Salvar como…", #selector(NoteWindowController.saveNoteAs(_:)), "s", [.command, .shift]),
        ]))

        main.addItem(submenu("Editar", [
            item("Desfazer", Selector(("undo:")), "z"),
            item("Refazer", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Recortar", #selector(NSText.cut(_:)), "x"),
            item("Copiar", #selector(NSText.copy(_:)), "c"),
            item("Colar", #selector(NSTextView.pasteAsPlainText(_:)), "v"),
            item("Selecionar tudo", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            finder("Localizar…", .showFindInterface, "f"),
            finder("Localizar e substituir…", .showReplaceInterface, "f", [.command, .option]),
            finder("Localizar próximo", .nextMatch, "g"),
            finder("Localizar anterior", .previousMatch, "g", [.command, .shift]),
        ]))

        main.addItem(submenu("Formatar", [
            item("Negrito", #selector(NoteWindowController.toggleBold(_:)), "b"),
            item("Marcadores", #selector(NoteWindowController.toggleBullets(_:)), "l", [.command, .shift]),
        ]))

        // ⌘= também aumenta (no teclado, o + costuma exigir Shift).
        let zoomInAlias = item("Aumentar zoom", #selector(NoteWindowController.zoomIn(_:)), "=")
        zoomInAlias.isHidden = true
        zoomInAlias.allowsKeyEquivalentWhenHidden = true
        main.addItem(submenu("Exibir", [
            item("Aumentar zoom", #selector(NoteWindowController.zoomIn(_:)), "+"),
            zoomInAlias,
            item("Diminuir zoom", #selector(NoteWindowController.zoomOut(_:)), "-"),
            item("Tamanho real", #selector(NoteWindowController.zoomReset(_:)), "0"),
        ]))

        let windowItem = submenu("Janela", [
            item("Minimizar", #selector(NSWindow.performMiniaturize(_:)), "m"),
        ])
        main.addItem(windowItem)
        NSApp.windowsMenu = windowItem.submenu

        return main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String = "",
                             _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    /// Item da barra de busca do macOS (a ação vai na tag).
    private static func finder(_ title: String, _ action: NSTextFinder.Action, _ key: String,
                               _ modifiers: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let finderItem = item(title, #selector(NSResponder.performTextFinderAction(_:)), key, modifiers)
        finderItem.tag = action.rawValue
        return finderItem
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
