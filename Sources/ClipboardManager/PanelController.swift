import AppKit
import SwiftUI

final class PanelController {
    private var panel: ClipboardPanel?
    let state = PanelState()
    private var previousApp: NSRunningApplication?

    private let fullHeight: CGFloat  = 480
    private let titleHeight: CGFloat = 36
    private let panelWidth: CGFloat  = 520

    func toggle() {
        panel?.isVisible == true ? close() : open()
    }

    func open() {
        previousApp = NSWorkspace.shared.frontmostApplication
        state.reset()
        state.requestSearchFocus()

        if panel == nil { buildPanel() }
        centerOnScreen()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    // MARK: - Build

    private func buildPanel() {
        let rootView = PanelView(
            state: state,
            onPaste:        { [weak self] items in self?.paste(items: items) },
            onSnippetPaste: { [weak self] text in self?.pasteText(text) },
            onClose:        { [weak self] in self?.close() },
            onCollapse:     { [weak self] collapsed in self?.setCollapsed(collapsed) }
        )

        let p = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: fullHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.onEscape = { [weak self] in self?.close() }

        // Tastatur-Events auf Panel-Ebene abfangen — vor dem SwiftUI-Responder
        p.keyHandler = { [weak self] event, inTextInput -> Bool in
            guard let self else { return false }
            return self.handleKey(event, inTextInput: inTextInput)
        }

        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false
        p.contentViewController = NSHostingController(rootView: rootView)
        self.panel = p
    }

    // MARK: - Collapse / Expand

    func setCollapsed(_ collapsed: Bool) {
        guard let panel = panel else { return }
        let targetHeight: CGFloat = collapsed ? titleHeight : fullHeight
        let currentFrame = panel.frame
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetHeight,
            width: panelWidth,
            height: targetHeight
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Key Handling

    private func handleKey(_ event: NSEvent, inTextInput: Bool) -> Bool {
        if event.keyCode == 53 { close(); return true }  // Esc

        // Snippets-Tab, Hilfe und Formulare: die Tasten gehören dem fokussierten Feld
        guard state.listNavigationActive else { return false }

        switch event.keyCode {
        case 125: state.moveDown();          return true  // ↓
        case 126: state.moveUp();            return true  // ↑
        case 36, 76: pasteSelection();       return true  // Return / Enter
        case 49:                                          // Leertaste
            // In der Suche ist Leertaste ein normales Zeichen — außer das Feld ist noch leer
            guard !inTextInput || state.searchText.isEmpty else { return false }
            state.toggleHighlighted()
            return true
        default:  return false
        }
    }

    private func pasteSelection() {
        let items = state.selectedItems()
        paste(items: items.isEmpty ? [state.highlightedItem()].compactMap { $0 } : items)
    }

    // MARK: - Layout

    private func centerOnScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.visibleFrame
        let x = f.minX + (f.width  - panelWidth)  / 2
        let y = f.minY + (f.height - fullHeight) / 2 + 60
        panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: fullHeight), display: false)
    }

    // MARK: - Paste

    private func paste(items: [ClipboardItem]) {
        guard !items.isEmpty else { return }

        let pb = NSPasteboard.general
        pb.clearContents()

        let texts = items.compactMap(\.text)
        if !texts.isEmpty {
            ClipboardMonitor.shared.ignoreNext()
            pb.setString(texts.joined(separator: "\n"), forType: .string)
            // move each pasted item to top so history reflects last used
            for item in items.reversed() {
                ClipboardStore.shared.moveToTop(id: item.id)
            }
        } else if let imgData = items.first?.imageData,
                  let nsImage = NSImage(data: imgData) {
            ClipboardMonitor.shared.ignoreNext()
            if let tiff = nsImage.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
            if let first = items.first {
                ClipboardStore.shared.moveToTop(id: first.id)
            }
        }

        close()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.previousApp?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Self.simulateCmdV()
            }
        }
    }

    func pasteText(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        ClipboardMonitor.shared.ignoreNext()
        pb.setString(text, forType: .string)
        close()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.previousApp?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                Self.simulateCmdV()
            }
        }
    }

    private static func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let v = CGKeyCode(0x09)
        let dn = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        dn?.flags = .maskCommand
        up?.flags = .maskCommand
        dn?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - ClipboardPanel

final class ClipboardPanel: NSPanel {
    var onEscape: (() -> Void)?
    var keyHandler: ((NSEvent, _ inTextInput: Bool) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    // sendEvent läuft VOR jedem Responder — auch dem SwiftUI TextField.
    // Der Handler bekommt mit, ob gerade ein Textfeld fokussiert ist, und entscheidet selbst,
    // welche Tasten er übernimmt (Pfeile/Enter auch bei fokussierter Suche, Tippen bleibt beim Feld).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let editor = firstResponder as? NSTextView
            let inTextInput = editor != nil || firstResponder is NSTextField
            // Bei Akzent-/IME-Eingabe (markierter Text) gehören alle Tasten dem Textfeld
            if editor?.hasMarkedText() != true, keyHandler?(event, inTextInput) == true { return }
        }
        super.sendEvent(event)
    }
}
