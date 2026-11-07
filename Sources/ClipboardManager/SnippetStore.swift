import Foundation
import Combine
import CryptoKit

final class SnippetStore: ObservableObject {
    static let shared = SnippetStore()

    @Published private(set) var snippets: [Snippet] = []
    private let saveURL: URL
    private let encryptionKey = KeychainHelper.loadOrCreateKey()

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("ClipFlow")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("snippets.json")
        load()
    }

    func add(_ snippet: Snippet) {
        snippets.insert(snippet, at: 0)
        save()
    }

    func remove(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func update(_ snippet: Snippet) {
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        var updated = snippet
        updated.updatedAt = Date()
        snippets[idx] = updated
        save()
    }

    func filtered(by query: String) -> [Snippet] {
        query.isEmpty ? snippets : snippets.filter { $0.matches(query) }
    }

    private func save() {
        let snapshot = snippets
        let url = saveURL
        let key = encryptionKey
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(snapshot),
                  let sealed = try? AES.GCM.seal(data, using: key).combined
            else { return }
            try? sealed.write(to: url, options: .atomic)
        }
    }

    private func load() {
        guard let raw = try? Data(contentsOf: saveURL) else { return }

        if let box = try? AES.GCM.SealedBox(combined: raw),
           let data = try? AES.GCM.open(box, using: encryptionKey),
           let loaded = try? JSONDecoder().decode([Snippet].self, from: data) {
            snippets = loaded
            return
        }

        // Migration: Datei stammt noch aus einer Version ohne Verschlüsselung (Klartext-JSON).
        guard let loaded = try? JSONDecoder().decode([Snippet].self, from: raw) else { return }
        snippets = loaded
        save() // sofort verschlüsselt neu schreiben
    }
}
