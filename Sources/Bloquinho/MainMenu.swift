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
        ]))

        main.addItem(submenu("Formatar", [
            item("Negrito", #selector(NoteWindowController.toggleBold(_:)), "b"),
            item("Marcadores", #selector(NoteWindowController.toggleBullets(_:)), "l", [.command, .shift]),
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

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
