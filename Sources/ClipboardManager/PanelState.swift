import Foundation
import Combine

final class PanelState: ObservableObject {
    @Published var searchText: String = "" {
        didSet { highlightedIndex = 0 }
    }
    @Published var selectedIDs: Set<UUID> = []
    @Published var highlightedIndex: Int = 0
    /// Wird bei jedem Öffnen erhöht — die Ansicht fokussiert daraufhin die Suche.
    @Published var searchFocusToken: Int = 0

    /// Vom PanelView gesetzt: true, solange die Verlaufsliste bedienbar ist
    /// (Verlaufs-Tab sichtbar, nicht eingeklappt, keine Hilfe, kein Overlay-Formular).
    var listNavigationActive = false

    private var cancellable: AnyCancellable?

    init() {
        // Re-publish store changes so views that observe PanelState also react to new items
        cancellable = ClipboardStore.shared.$items.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }

    var filteredItems: [ClipboardItem] {
        let all = ClipboardStore.shared.items
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.preview.localizedCaseInsensitiveContains(searchText) }
    }

    func moveUp()   { if highlightedIndex > 0 { highlightedIndex -= 1 } }
    func moveDown() { if highlightedIndex < filteredItems.count - 1 { highlightedIndex += 1 } }

    func toggleHighlighted() {
        guard let item = filteredItems[safe: highlightedIndex] else { return }
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else                             { selectedIDs.insert(item.id) }
    }

    func highlightedItem() -> ClipboardItem? { filteredItems[safe: highlightedIndex] }
    func selectedItems() -> [ClipboardItem]  { filteredItems.filter { selectedIDs.contains($0.id) } }

    func requestSearchFocus() { searchFocusToken += 1 }

    func reset() {
        searchText = ""
        selectedIDs = []
        highlightedIndex = 0
    }
}
