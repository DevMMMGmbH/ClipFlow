# ClipFlow

Eine schlanke macOS Menüleisten-App für Zwischenablagen-Verwaltung und Snippet-Management — entwickelt von Alex Misgin, gemeinsam mit [Claude (Anthropic)](https://claude.ai).

---

## Was ist ClipFlow?

ClipFlow sitzt unauffällig in deiner Menüleiste und merkt sich alles was du kopierst. Per Tastenkürzel öffnest du ein schwebendes Panel, suchst blitzschnell und fügst Einträge direkt in jede App ein — ohne Maus, ohne Ablenkung.

Zusätzlich gibt es einen **Snippet-Manager** für Texte die du immer wieder brauchst: SSH-Befehle, Passwörter, Server-URLs, Composer-Kommandos — alles abrufbar per Klick, geordnet nach Projekten und Tags.

---

## Features

### Verlauf
- Speichert automatisch alles was du kopierst (Text & Bilder)
- Sofortsuche über alle Einträge
- Mehrfachauswahl mit `Leertaste` oder `⌘ + Klick` → zusammen einfügen
- Zuletzt eingefügter Eintrag wandert automatisch nach oben
- **Lorem Ipsum Button** zum schnellen Befüllen von Testfeldern
- Konfigurierbare Verlaufsgröße (10–500 Einträge)

### Snippet-Manager
- Eigener Tab für dauerhaft gespeicherte Texte
- Jeder Snippet hat: **Titel**, **Inhalt**, **Projekt** und **Tags**
- **Autocomplete** für Projekt und Tags — Vorschläge aus bereits gespeicherten Snippets
- Aus dem Verlauf heraus direkt als Snippet speichern (Bookmark-Icon beim Hover)
- Snippets bearbeiten und löschen
- Suche filtert über alle Felder gleichzeitig

### Bedienung
| Aktion | Kürzel |
|--------|--------|
| Panel öffnen / schließen | `⌃⌘V` (anpassbar) |
| Panel schließen | `Esc` |
| Navigieren | `↑` `↓` |
| Einfügen | `↩ Return` |
| Eintrag markieren | `Leertaste` (bei leerer Suche) |
| Mehrfachauswahl | `⌘ + Klick` |

---

## Installation

> **Voraussetzung:** macOS 14 (Sonoma) oder neuer

### 1. DMG herunterladen

Gehe zu [Releases](https://github.com/DevMMMGmbH/paste_misgin.local/releases) und lade die neueste `.dmg`-Datei herunter.

### 2. App installieren

DMG öffnen → **ClipFlow** in den **Programme**-Ordner ziehen.

### 3. Quarantäne-Flag entfernen *(einmalig)*

Da ClipFlow nicht über den Mac App Store verteilt wird, blockiert macOS die App beim ersten Start. Das lässt sich mit einem einzigen Terminal-Befehl beheben:

```bash
xattr -cr /Applications/ClipFlow.app
```

### 4. Starten & Berechtigung erteilen

ClipFlow starten → macOS fragt nach Zugriff auf **Bedienungshilfen** → erlauben.

Diese Berechtigung ist nötig damit ClipFlow beim Einfügen automatisch `⌘V` simulieren kann. Sie muss nur einmal erteilt werden und bleibt auch nach Updates bestehen.

---

## Selbst bauen

```bash
git clone https://github.com/DevMMMGmbH/paste_misgin.local.git
cd paste_misgin.local
./build_dmg.sh
```

Voraussetzung: Xcode Command Line Tools (`xcode-select --install`)

---

## Changelog

### Version 1.2.3
- Fix: Pfeiltasten funktionieren jetzt sofort nach dem Öffnen des Panels, auch bei fokussierter Suche (kein Tab-Wechsel mehr nötig)
- Die Suche wird beim Öffnen und beim Zurückwechseln auf „Verlauf“ zuverlässig fokussiert
- `Return` fügt auf dem Snippets-Tab keinen Verlaufseintrag mehr ein
- Leertaste markiert nur noch bei leerer Suche, sonst wird ein Leerzeichen getippt

### Version 1.2.2
- Autocomplete für Projekt und Tags im Snippet-Formular

### Version 1.2.1
- Paste (`⌘V`) funktioniert jetzt im Snippet-Formular
- Snippets bearbeiten (Stift-Icon beim Hover)
- Aus dem Verlauf als Snippet speichern (Bookmark-Icon beim Hover)
- Mehrzeiliger Inhalt-Editor im Formular

### Version 1.2
- **Snippet-Manager** — neuer Tab mit Projekten, Tags und Suche
- Lorem Ipsum Button in der Suchleiste
- Zuletzt eingefügter Eintrag wird automatisch nach oben verschoben

### Version 1.1
- Universal Binary (Apple Silicon + Intel)
- Stabiles Code-Signing für persistente Bedienungshilfen-Berechtigung
- Verlaufsmigration von alter App-Version

### Version 1.0
- Erster Release: Menüleisten-App, Tastenkürzel, Mehrfachauswahl, Suche

---

## Entwickelt mit Claude

Dieses Projekt wurde von **Alex Misgin** zusammen mit **[Claude](https://claude.ai)** (Anthropic) entwickelt — einem KI-Assistenten der direkt im Terminal läuft und bei Architektur, Code und Debugging hilft.

---

## Lizenz

Privates Projekt — keine offizielle Lizenz. Nutzung auf eigene Verantwortung.
