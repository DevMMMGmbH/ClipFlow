import AppKit
import SwiftUI

/// Breiter, leicht greifbarer Rand zum Größe-Ändern per Maus.
/// Der native Resize-Rand eines randlosen (`.borderless`) Fensters ist nur
/// wenige Pixel breit und dadurch kaum zu treffen — diese Handles liegen als
/// unsichtbare Streifen über dem Fensterrand und ziehen das Fenster direkt.
enum ResizeEdge {
    case left, right, bottom, bottomLeft, bottomRight

    var cursor: NSCursor {
        switch self {
        case .left, .right:                 return .resizeLeftRight
        case .bottom:                       return .resizeUpDown
        case .bottomLeft, .bottomRight:      return .resizeLeftRight // kein diagonaler System-Cursor verfügbar
        }
    }
}

struct ResizeHandleArea: NSViewRepresentable {
    let edge: ResizeEdge

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        view.edge = edge
        return view
    }

    func updateNSView(_ nsView: HandleView, context: Context) {
        nsView.edge = edge
    }

    final class HandleView: NSView {
        var edge: ResizeEdge = .right
        private var startFrame: NSRect = .zero
        private var startLocation: NSPoint = .zero
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.activeAlways, .mouseEnteredAndExited, .cursorUpdate],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func cursorUpdate(with event: NSEvent) {
            edge.cursor.set()
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            startFrame = window.frame
            startLocation = NSEvent.mouseLocation
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let current = NSEvent.mouseLocation
            let dx = current.x - startLocation.x
            let dy = current.y - startLocation.y
            let minWidth  = window.minSize.width
            let minHeight = window.minSize.height

            var newFrame = startFrame

            if edge == .left || edge == .bottomLeft {
                let newWidth = max(minWidth, startFrame.width - dx)
                newFrame.origin.x = startFrame.maxX - newWidth
                newFrame.size.width = newWidth
            }
            if edge == .right || edge == .bottomRight {
                newFrame.size.width = max(minWidth, startFrame.width + dx)
            }
            if edge == .bottom || edge == .bottomLeft || edge == .bottomRight {
                let newHeight = max(minHeight, startFrame.height - dy)
                newFrame.origin.y = startFrame.maxY - newHeight
                newFrame.size.height = newHeight
            }

            window.setFrame(newFrame, display: true)
        }
    }
}
