# PlasmaLogo

A macOS-style system menu for KDE Plasma 6: a panel button with your
distribution logo that opens a menu with quick system actions, and an
"About This Computer" window of its own (no KInfoCenter needed, though it is
one click away).

Written in plain QML (no compiled plugin).

## Features

- Menu with the classic layout, grouped by separators:
  About This Computer · System Settings… · App Store… · Force Quit… ·
  Sleep · Hibernate · Restart… · Shut Down… · Lock Screen · Log Out…
- Opens as a regular Plasma applet popup (theme background, corners and
  shadow), sized to its longest entry. The highlighted entry uses the theme's
  accent color; arrow keys, Enter and Esc work as in a menu.
- "About This Computer" opens in its own window in the center of the screen:
  distribution logo and name, Plasma and kernel versions, model, processor,
  memory, graphics, storage, computer name and uptime, plus a
  "More Information…" button that opens KInfoCenter. Closes with Esc, the
  close button or a click outside.
- Restart, Shut Down and Log Out ask for confirmation in a card inside the
  popup.
- Actions the computer does not support (e.g. Hibernate without a swap setup)
  are hidden, or shown disabled if you prefer (widget settings).
- Force Quit uses KWin's "Kill Window" picker on Wayland and `xkill` on X11.
- Configurable panel icon and icon size.
- Translations: Brazilian Portuguese, German, French, Spanish, Russian,
  Simplified Chinese, Italian, Polish, Japanese, European Portuguese, Dutch,
  Turkish, Ukrainian, Czech, Korean and Traditional Chinese.

## Requirements

- KDE Plasma 6 (developed and tested on Plasma 6.7.5, Fedora 44 Kinoite,
  Wayland).
- `busctl` (systemd) for the logind capability checks; `notify-send` to report
  errors; KInfoCenter and Discover for the matching entries.

## Installation

From the release file:

```sh
kpackagetool6 --type Plasma/Applet --install io.github.khryzantema.plasmalogo-1.0.0.plasmoid
```

From a clone of this repository:

```sh
kpackagetool6 --type Plasma/Applet --install package    # first time
kpackagetool6 --type Plasma/Applet --upgrade package    # updates
```

Then right-click the panel → **Add or Manage Widgets…** → search for
**PlasmaLogo** and drag it to the left end of the panel. After upgrading,
restart Plasma to load the new version:

```sh
systemctl --user restart plasma-plasmashell
```

## How it works

- `contents/ui/main.qml`: panel button, session actions, system information.
- `contents/ui/FullRepresentation.qml`: the menu popup.
- `contents/ui/AboutDialog.qml` / `AboutContent.qml`: the centered window.
- `contents/scripts/`: small shell scripts that each print one JSON object,
  called asynchronously through the `executable` engine of
  `org.kde.plasma.plasma5support`:
  - `sysinfo.sh`: data for "About This Computer";
  - `syscaps.sh`: what systemd-logind says the computer supports;
  - `forcequit.sh`: Force Quit.

To check the scripts on their own:

```sh
sh package/contents/scripts/sysinfo.sh
sh package/contents/scripts/syscaps.sh
```

## Private APIs used

| Feature | Module | Status |
|---|---|---|
| Sleep, hibernate, restart, shut down, lock, log out | `org.kde.plasma.private.sessions` (plasma-workspace) | private |
| Capability checks (fallback) | systemd-logind over DBus | stable |
| Force Quit on Wayland | KWin's "Kill Window" shortcut through `org.kde.kglobalaccel` | internal |

The session module is loaded through a `Loader`: if it changes or disappears
in a future Plasma release, the menu keeps working with the logind checks and
shows a notification when an action cannot run.

## Known limitations

- Restart, Shut Down and Log Out may ask twice if Plasma's own "confirm logout"
  setting is enabled (once in the menu, once in Plasma's logout screen).
- Force Quit relies on an internal KWin shortcut name ("Kill Window"), which may
  change between KWin versions.

## Development

- `probe.sh <snippet.qml> <workdir>`: runs a throwaway copy of the widget
  offscreen with extra QML injected (used for testing without opening windows).
- `tools/i18n.py extract | update | compile`: translation workflow without
  gettext. User-visible strings are English in the code (`i18n()`);
  translations live in `po/<language>.po` and are compiled into
  `package/contents/locale/`.

## License

GPL-2.0-or-later.
