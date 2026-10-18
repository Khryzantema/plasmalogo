#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# "Force Quit": lets the user click a window to kill it.
#
# On X11, xkill does exactly that. On Wayland there is no native xkill (it
# relies on X11 atoms that pure Wayland windows do not have), so this triggers
# KWin's own "Kill Window" picker (System Settings > Shortcuts > KWin, the same
# one KSysGuard's "Kill Process" used) through DBus/kglobalaccel. It is an
# internal KWin shortcut, not a stable public API, so it may change between
# versions.

SESSION_TYPE="${XDG_SESSION_TYPE:-}"
if [ -z "$SESSION_TYPE" ] && command -v loginctl >/dev/null 2>&1; then
    SESSION_TYPE=$(loginctl show-session "${XDG_SESSION_ID:-self}" -p Type --value 2>/dev/null)
fi

if [ "$SESSION_TYPE" = "wayland" ]; then
    if command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Kill Window" 2>/dev/null && exit 0
    fi
    if command -v qdbus >/dev/null 2>&1; then
        qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Kill Window" 2>/dev/null && exit 0
    fi
    if command -v busctl >/dev/null 2>&1; then
        busctl --user call org.kde.kglobalaccel /component/kwin \
            org.kde.kglobalaccel.Component invokeShortcut s "Kill Window" 2>/dev/null && exit 0
    fi
    echo "Could not trigger KWin's 'Kill Window' on this system." >&2
    exit 1
else
    if command -v xkill >/dev/null 2>&1; then
        exec xkill
    fi
    echo "xkill is not installed on this system." >&2
    exit 1
fi
