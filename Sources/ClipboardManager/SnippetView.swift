import SwiftUI
import AppKit

struct SnippetView: View {
    @ObservedObject private var store = SnippetStore.shared
    var onPaste: (String) -> Void

    @State private var searchText = ""
    @State private var showAdd = false
    @State private var editingSnippet: Snippet? = nil

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if store.filtered(by: searchText).isEmpty {
                emptyState
            } else {
                snippetList
            }
        }
        .frame(maxHeight: .infinity)
        .overlay {
            if showAdd {
                AddSnippetOverlay(isPresented: $showAdd, existing: nil) { snippet in
                    store.add(snippet)
                }
            } else if let snippet = editingSnippet {
                AddSnippetOverlay(isPresented: Binding(
                    get: { editingSnippet != nil },
                    set: { if !$0 { editingSnippet = nil } }
                ), existing: snippet) { updated in
                    store.update(updated)
                    editingSnippet = nil
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
            TextField("Suchen…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Snippet hinzufügen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - List

    private var snippetList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.filtered(by: searchText)) { snippet in
                    SnippetRow(snippet: snippet) {
                        onPaste(snippet.content)
                    } onEdit: {
                        editingSnippet = snippet
                    } onDelete: {
                        store.remove(id: snippet.id)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Keine Snippets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { showAdd = true } label: {
                Label("Snippet hinzufügen", systemImage: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Snippet Row

struct SnippetRow: View {
    let snippet: Snippet
    let onPaste: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor.opacity(0.7))
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(snippet.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if !snippet.project.isEmpty {
                        Text(snippet.project)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(snippet.project.stableAccent.gradient, in: Capsule())
                    }
                }
                Text(snippet.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !snippet.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(snippet.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(tag.stableAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(tag.stableAccent.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Bearbeiten")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Löschen")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.035))
        )
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0), radius: 6, y: 2)
        .contentShape(Rectangle())
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
        .onTapGesture { onPaste() }
    }
}

// MARK: - Autocomplete Field

struct AutocompleteField: View {
    let label: String
    let placeholder: String
    let suggestions: [String]
    @Binding var text: String
    /// Wenn true: Komma-getrennte Tags — Autocomplete gilt nur für das letzte Token
    var isTagMode: Bool = false

    @State private var showSuggestions = false
    @FocusState private var focused: Bool

    private var filtered: [String] {
        let query = isTagMode ? currentToken : text
        guard !query.isEmpty else { return suggestions }
        return suggestions.filter { $0.lowercased().hasPrefix(query.lowercased()) && $0 != query }
    }

    /// Das Token das gerade getippt wird (letztes Element nach dem letzten Komma)
    private var currentToken: String {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        return parts.last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(7)
                    .focused($focused)
                    .onChange(of: text) { _, _ in showSuggestions = focused && !filtered.isEmpty }
                    .onChange(of: focused) { _, isFocused in
                        showSuggestions = isFocused && !filtered.isEmpty
                    }

                if showSuggestions && !filtered.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered.prefix(5), id: \.self) { suggestion in
                            Button {
                                apply(suggestion)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isTagMode ? "tag" : "folder")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                    Text(suggestion)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color.accentColor.opacity(0.001)) // tappable area
                            .onHover { hovered in
                                // highlight on hover handled by buttonStyle
                            }
                        }
                    }
                }
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(focused ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.12), value: showSuggestions)
        }
    }

    private func apply(_ suggestion: String) {
        if isTagMode {
            // Alle vorherigen Tags behalten, letztes Token ersetzen
            var parts = text.split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if !parts.isEmpty { parts[parts.count - 1] = suggestion }
            text = parts.joined(separator: ", ") + ", "
        } else {
            text = suggestion
        }
        showSuggestions = false
    }
}

// MARK: - Add / Edit Overlay

struct AddSnippetOverlay: View {
    @Binding var isPresented: Bool
    var existing: Snippet?
    var prefillContent: String? = nil
    var onSave: (Snippet) -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var project = ""
    @FocusState private var titleFocused: Bool

    @ObservedObject private var store = SnippetStore.shared

    var isEditing: Bool { existing != nil }

    private var allProjects: [String] {
        Array(Set(store.snippets.map(\.project).filter { !$0.isEmpty })).sorted()
    }

    private var allTags: [String] {
        Array(Set(store.snippets.flatMap(\.tags))).sorted()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                    Text(isEditing ? "Snippet bearbeiten" : "Snippet hinzufügen")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    formSection(header: "Inhalt") {
                        // Titel
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Titel")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("z.B. SSH Produktiv-Server", text: $title)
                                .focused($titleFocused)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(7)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        }

                        // Inhalt
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Inhalt")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("ssh user@1.2.3.4 -p 22")
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $content)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(minHeight: 70, maxHeight: 140)
                                    .scrollContentBackground(.hidden)
                                    .padding(4)
                            }
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        }
                    }

                    Divider()

                    formSection(header: "Organisation") {
                        // Projekt mit Autocomplete
                        AutocompleteField(
                            label: "Projekt",
                            placeholder: "z.B. misgin.local",
                            suggestions: allProjects,
                            text: $project
                        )

                        // Tags mit Autocomplete
                        AutocompleteField(
                            label: "Tags",
                            placeholder: "ssh, server, prod  (kommagetrennt)",
                            suggestions: allTags,
                            text: $tags,
                            isTagMode: true
                        )
                    }
                }
                .padding(18)

                Divider()

                HStack {
                    Spacer()
                    Button("Abbrechen") { isPresented = false }
                    Button(isEditing ? "Speichern" : "Hinzufügen") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(title.isEmpty || content.isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .frame(width: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
            .padding(20)
            .onAppear {
                if let s = existing {
                    title   = s.title
                    content = s.content
                    project = s.project
                    tags    = s.tagString
                } else {
                    if let pre = prefillContent { content = pre }
                    titleFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(header.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func save() {
        let parsedTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if var updated = existing {
            updated.title   = title
            updated.content = content
            updated.tags    = parsedTags
            updated.project = project
            onSave(updated)
        } else {
            onSave(Snippet(title: title, content: content, tags: parsedTags, project: project))
        }
        isPresented = false
    }
}
