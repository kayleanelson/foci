# foci

One macOS login, two setups. A menu bar switch that, for the profile you pick:

- quits the other profile's apps (it never opens any)
- sets this profile's wallpaper
- restores this profile's Dock
- reopens Obsidian on this profile's vault

## Install

```bash
make app
```

This builds `build/Foci.app`. Move it to `/Applications` and open it. Choose
**Edit Config…** from its menu, which puts an example config at
`~/Library/Application Support/foci/config.json` for you to edit:

```json
{
  "profiles": {
    "work": {
      "symbol": "briefcase.fill",
      "wallpaper": "~/Pictures/Wallpapers/work.heic",
      "obsidianVault": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YCRC",
      "apps": ["com.tinyspeck.slackmacgap", "com.microsoft.Outlook"]
    },
    "personal": { "symbol": "house.fill", "apps": ["com.apple.MobileSMS"] }
  }
}
```

- **apps**: bundle IDs of apps that belong to this profile, quit when you
  switch to another. Apps listed in both profiles, or in neither, are never
  quit. Find an app's ID with `osascript -e 'id of app "Slack"'`.
- **symbol**: an SF Symbol name, shown in the menu bar.
- **obsidianVault**, **wallpaper**: optional paths. `~` is allowed.

Turn on **Launch at Login** from the menu.

## The Dock

There's nothing to configure. Arrange the Dock by hand while you're in a
profile; it's saved when you switch away and restored when you come back.
The first time you enter a profile it keeps the Dock as it is. To save the
current Dock as a profile's immediately:

```bash
/Applications/Foci.app/Contents/Resources/foci capture-dock work
```

## Following Focus (optional)

Off by default: a scheduled Focus never switches you in the middle of late
work or on a holiday. To have Focus drive switching:

1. Shortcuts → Automation → New → **Focus** → Work → *When Turning On* →
   **Run Immediately**.
2. Action: **Run Shell Script**:
   `/Applications/Foci.app/Contents/Resources/foci switch work --source focus`
3. Do the same for Personal.
4. Tick **Follow Focus** in the Foci menu.

Unticking Follow Focus turns this off without removing the automations; a
`--source focus` request does nothing while it's off.

## CLI

```
foci status
foci switch <profile> [--force]
foci capture-dock [<profile>]
foci follow-focus on|off
```

## Limits

- Wallpaper changes only the current Space on each display. That's a macOS
  restriction.
- Apps are asked to quit, never force-quit. One with unsaved work shows its
  prompt; if it hasn't quit after 20 seconds the switch reports it and
  continues.
- Obsidian is reopened only if it was already running. Otherwise the vault is
  set and Obsidian opens on it the next time you start it.
