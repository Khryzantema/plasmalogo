/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

// Kept in its own file on purpose: if the private module
// org.kde.plasma.private.sessions is missing or renamed in a Plasma release,
// only the Loader that loads this file fails (Loader.Error). The rest of the
// widget keeps working: power entries fall back to the logind checks
// (syscaps.sh) and show an error notification when an action cannot run.
import org.kde.plasma.private.sessions as Sessions

Sessions.SessionManagement {
    id: session
}
