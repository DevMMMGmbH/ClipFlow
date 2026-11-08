import AppKit
import SwiftUI

final class PanelController {
    private var panel: ClipboardPanel?
    let state = PanelState()
    private var previousApp: NSRunningApplication?

    private let defaultWidth: CGFloat  = 520
    private let defaultHeight: CGFloat = 480
    private let titleHeight: CGFloat   = 36
    private let minWidth: CGFloat      = 440
    private let minHeight: CGFloat     = 360

    private static let frameDefaultsKey = "panelFrame"

    /// Zuletzt bekannte Größe/Position im ausgeklappten Zustand — wird persistiert
    /// und ist die Grundlage für die Höhe beim Ein-/Ausklappen.
    private var expandedFrame: NSRect = .zero
    private var isCollapsed = false

    func toggle() {
        panel?.isVisible == true ? close() : open()
    }

    func open() {
        previousApp = NSWorkspace.shared.frontmostApplication
        state.reset()
        state.requestSearchFocus()

        if panel == nil { buildPanel() }
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
            onPasteToApp:   { [weak self] app in self?.pasteSelectionToApp(app) },
            onSnippetPaste: { [weak self] text in self?.pasteText(text) },
            onClose:        { [weak self] in self?.close() },
            onCollapse:     { [weak self] collapsed in self?.setCollapsed(collapsed) }
        )

        let restored = restoredFrame()
        let initialFrame = restored ?? NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight)
        expandedFrame = initialFrame

        let p = ClipboardPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        p.minSize = NSSize(width: minWidth, height: minHeight)
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

        let hosting = NSHostingController(rootView: rootView)
        // Verhindert, dass NSHostingController die Fenstergröße eigenmächtig an die
        // "ideale" SwiftUI-Content-Größe anpasst — die Größe bestimmen wir selbst
        // (initialFrame / Resize-Handles), sonst schrumpft das Panel beim Layout
        // ungewollt auf die Mindestgröße.
        hosting.sizingOptions = []
        p.contentViewController = hosting
        self.panel = p

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: p, queue: .main
        ) { [weak self] _ in self?.persistFrameIfNeeded() }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification, object: p, queue: .main
        ) { [weak self] _ in self?.persistFrameIfNeeded() }

        if restored == nil { centerOnScreen() }
    }

    // MARK: - Größe & Position merken

    private func persistFrameIfNeeded() {
        guard let panel, !isCollapsed else { return }
        expandedFrame = panel.frame
        UserDefaults.standard.set(NSStringFromRect(expandedFrame), forKey: Self.frameDefaultsKey)
    }

    private func restoredFrame() -> NSRect? {
        guard let saved = UserDefaults.standard.string(forKey: Self.frameDefaultsKey) else { return nil }
        let rect = NSRectFromString(saved)
        guard rect.width >= minWidth, rect.height >= minHeight else { return nil }
        return rect
    }

    // MARK: - Collapse / Expand

    func setCollapsed(_ collapsed: Bool) {
        guard let panel else { return }
        isCollapsed = collapsed

        let targetHeight: CGFloat = collapsed ? titleHeight : expandedFrame.height
        let targetWidth: CGFloat  = collapsed ? panel.frame.width : expandedFrame.width
        let currentFrame = panel.frame
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - targetHeight,
            width: targetWidth,
            height: targetHeight
        )
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }, completionHandler: { [weak self] in
            if !collapsed { self?.persistFrameIfNeeded() }
        })
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

    /// Fügt die aktuelle Auswahl (oder den markierten Eintrag) gezielt in eine
    /// bestimmte laufende App ein, statt in die zuletzt aktive App.
    func pasteSelectionToApp(_ app: NSRunningApplication) {
        let items = state.selectedItems()
        paste(items: items.isEmpty ? [state.highlightedItem()].compactMap { $0 } : items, target: app)
    }

    // MARK: - Layout

    private func centerOnScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let f = screen.visibleFrame
        let x = f.minX + (f.width  - defaultWidth)  / 2
        let y = f.minY + (f.height - defaultHeight) / 2 + 60
        panel?.setFrame(NSRect(x: x, y: y, width: defaultWidth, height: defaultHeight), display: false)
    }

    // MARK: - Paste

    private func paste(items: [ClipboardItem], target: NSRunningApplication? = nil) {
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

        let targetApp = target ?? previousApp
        let isExplicitTarget = target != nil

        // Beim Wechsel in eine über die App-Leiste gewählte App (oft länger inaktiv)
        // braucht die Aktivierung spürbar länger als beim Zurückkehren zur zuletzt
        // aktiven App — daher hier mehr Zeit einplanen.
        let activateDelay: TimeInterval = isExplicitTarget ? 0.15 : 0.08
        let pasteDelay: TimeInterval    = isExplicitTarget ? 0.2  : 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + activateDelay) {
            targetApp?.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
                let isBrowser = isExplicitTarget
                    && targetApp?.bundleIdentifier.map(Self.browserBundleIDs.contains) == true
                if isBrowser {
                    // Adressleiste fokussieren, sonst landet der Paste ggf. nirgends
                    Self.simulateCmdL()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        Self.simulateCmdV()
                    }
                } else {
                    Self.simulateCmdV()
                }
            }
        }
    }

    private static let browserBundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta",
        "com.apple.Safari",
        "company.thebrowser.Browser",     // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
    ]

    private static func simulateCmdL() {
        let src = CGEventSource(stateID: .hidSystemState)
        let l = CGKeyCode(0x25) // kVK_ANSI_L
        let dn = CGEvent(keyboardEventSource: src, virtualKey: l, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: l, keyDown: false)
        dn?.flags = .maskCommand
        up?.flags = .maskCommand
        dn?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
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
