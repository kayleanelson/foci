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

This builds `build/Foci.app`. Move it to `/Applications` and open it, then choose
**Settings…** (⌘,) from its menu bar icon. Opening Foci again while it's running
also opens Settings, which helps if Bartender has hidden the icon.

Each profile has:

- **Name** and **icon**: shown in the menu bar.
- **Wallpaper**: the starting wallpaper. Change the wallpaper while you're in a
  profile and that's saved when you switch away; choosing one in Settings
  replaces it (and applies immediately to the profile you're in).
- **Obsidian vault**: opened when you switch in.
- **Apps**: quit when you switch to another profile. Apps listed in more than
  one profile, or in none, are never quit.

Settings saves to `~/Library/Application Support/foci/config.json`, which you
can still edit by hand (`config.example.json` shows the format).

Turn on **Launch at Login** from the menu.

## The Dock

Arrange the Dock by hand while you're in a profile; it's saved when you
switch away and restored when you come back. Whatever is restored, apps that
belong only to another profile are always taken out, so work apps never sit
in the personal Dock. The first time you enter a profile, it starts from the
current Dock with those apps removed. To save the current Dock as a profile's
immediately:

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
