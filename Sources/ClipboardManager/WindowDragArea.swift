import AppKit
import SwiftUI

/// Unsichtbarer Hintergrund, der das Fenster per Drag verschiebt.
/// SwiftUI-Views ohne eigene Geste (Text, Spacer, Icons) leiten Mausklicks
/// nicht an `isMovableByWindowBackground` weiter, da die NSHostingView sie
/// selbst konsumiert — deshalb hier direkt per `performDrag` auf NSView-Ebene.
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
