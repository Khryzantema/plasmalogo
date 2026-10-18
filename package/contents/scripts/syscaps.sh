#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Asks systemd-logind over DBus (no privileges needed) what the computer
# supports, as a complement to Plasma's SessionManagement.
# Prints JSON with "yes" | "no" | "challenge" | "na" | "" (unknown, when
# busctl fails or the service does not answer).

query() {
    # $1 = DBus method (CanSuspend, CanHibernate, CanReboot, CanPowerOff)
    if ! command -v busctl >/dev/null 2>&1; then
        printf ''
        return
    fi
    OUT=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager "$1" 2>/dev/null)
    printf '%s' "$OUT" | sed -n 's/^s "\(.*\)"$/\1/p'
}

printf '{"suspend":"%s","hibernate":"%s","reboot":"%s","poweroff":"%s"}\n' \
    "$(query CanSuspend)" \
    "$(query CanHibernate)" \
    "$(query CanReboot)" \
    "$(query CanPowerOff)"
