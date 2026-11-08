import SwiftUI

/// Deterministische Akzentfarbe aus einer kuratierten Palette — dieselbe
/// Zeichenkette (z.B. Projektname oder Tag) ergibt immer dieselbe Farbe,
/// sodass Projekte/Tags visuell unterscheidbar aber über Neustarts stabil sind.
extension StringProtocol {
    var stableAccent: Color {
        let palette: [Color] = [
            .red, .orange, .yellow, .green, .mint,
            .teal, .cyan, .blue, .indigo, .purple, .pink,
        ]
        let hash = unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[hash % palette.count]
    }
}
