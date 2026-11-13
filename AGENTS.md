# foci

Switches one macOS login between profiles (work, personal): quits the other
profile's apps, sets wallpaper, swaps the Dock, switches the Obsidian vault.
It never opens apps: she opens what she needs. Menu bar app plus a CLI over one
engine.

## Commands

- `make check` — lint, unit tests, build. Run before calling anything done.
- `make format` — apply swift-format. Commit reformatting on its own.
- `make app` — build `build/Foci.app` (menu bar app, CLI inside at
  `Contents/Resources/foci`).
- `swift run foci status` / `swift run foci switch work` — exercise the CLI.

## Layout

- `Sources/FociCore` — pure logic, Foundation only. Config, app plan, Dock and
  Obsidian transforms, CLI parsing, and `Switcher`, which talks to the machine
  only through the `System` and `Store` protocols.
- `Sources/FociSystem` — the real `System` (AppKit) and `FileStore`.
- `Sources/foci` — CLI. `Sources/FociMenu` — SwiftUI `MenuBarExtra` app.
- `Tests/FociCoreTests` — Swift Testing. `Switcher` is tested with a fake
  `System`, so tests never touch the real Dock, apps or wallpaper.

## Rules

- Running a switch changes the real desktop. Never run `foci switch` as a test.
- User data lives in `~/Library/Application Support/foci/`: `config.json` is
  hers and the tool never writes it; `state.json` (current profile, Follow
  Focus) and `docks/<profile>.plist` are the tool's.
- A Focus-triggered switch (`--source focus`) must do nothing unless Follow
  Focus is on. Her Focus modes are scheduled, and she works late and on
  holidays.
- Apps are identified by bundle ID, never by name or path.
