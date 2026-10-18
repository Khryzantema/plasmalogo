/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// "About This Computer" in its own window in the center of the screen, like on
// macOS, with the theme's popup background, corners and shadow. Closes with Esc,
// the close button or a click outside.
PlasmaCore.Dialog {
    id: dialog

    required property PlasmoidItem plasmoidItem

    // Same window role as applet popups (the Dialog would turn "Normal" into "Dock").
    type: PlasmaCore.Dialog.AppletPopup
    location: PlasmaCore.Types.Floating
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    visible: false

    // Free area of the screen the applet's panel is on (panels excluded).
    readonly property rect screenRect: {
        const containment = Plasmoid.containment;
        if (!containment) {
            return Qt.rect(0, 0, -1, -1);
        }
        return Qt.rect(containment.screenGeometry.x + containment.availableScreenRect.x,
                       containment.screenGeometry.y + containment.availableScreenRect.y,
                       containment.availableScreenRect.width,
                       containment.availableScreenRect.height);
    }

    function center() {
        if (screenRect.width <= 0) {
            return;
        }
        x = Math.round(screenRect.x + (screenRect.width - width) / 2);
        y = Math.round(screenRect.y + (screenRect.height - height) / 2);
    }

    function open() {
        plasmoidItem.refreshInfo();
        center();
        visible = true;
        Qt.callLater(() => {
            center();
            requestActivate();
            content.forceActiveFocus();
        });
    }

    onWidthChanged: if (visible) center()
    onHeightChanged: if (visible) center()

    mainItem: AboutContent {
        id: content
        info: dialog.plasmoidItem.info
        loading: dialog.plasmoidItem.infoLoading
        rows: dialog.plasmoidItem.infoRows
        onCloseRequested: dialog.visible = false
        onMoreInfoRequested: {
            dialog.visible = false;
            dialog.plasmoidItem.launch("kinfocenter");
        }
    }
}
