/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

import "components"

// The menu popup: a regular Plasma applet popup with the classic Apple menu
// layout. "About This Computer" opens in a centered window (AboutDialog).
PlasmaExtras.Representation {
    id: full

    required property PlasmoidItem plasmoidItem

    // Sized like a menu: the longest entry (icon + text + margins) plus 10%,
    // so it follows the language in use. The size never changes while open:
    // resizing the popup window makes Plasma move it, which flickers on Wayland.
    readonly property real menuWidth: Math.ceil(content.implicitWidth * 1.1) + Kirigami.Units.smallSpacing * 2
    Layout.minimumWidth: menuWidth
    Layout.preferredWidth: menuWidth
    Layout.maximumWidth: menuWidth
    Layout.minimumHeight: content.implicitHeight + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Layout.minimumHeight
    Layout.maximumHeight: Layout.minimumHeight
    collapseMarginsHint: true

    function openAbout() {
        plasmoidItem.expanded = false;
        plasmoidItem.openAbout();
    }

    // Closes the popup, then runs the action (so it does not stay over the app it opens).
    function run(action) {
        plasmoidItem.expanded = false;
        action();
    }

    Keys.onEscapePressed: plasmoidItem.expanded = false

    Connections {
        target: full.plasmoidItem
        function onExpandedChanged() {
            if (full.plasmoidItem.expanded) {
                full.plasmoidItem.refreshCaps();
                Qt.callLater(() => aboutRow.forceActiveFocus(Qt.TabFocusReason));
            }
        }
    }

    component MenuSeparator: Kirigami.Separator {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        Layout.leftMargin: Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.smallSpacing
    }

    Item {
        id: mainPage
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        implicitHeight: content.implicitHeight

        // The Apple menu layout: a list of entries grouped by separators.
        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            MenuRow {
                id: aboutRow
                Layout.fillWidth: true
                iconName: full.plasmoidItem.info.os_logo || "start-here-kde"
                text: i18n("About This Computer")
                onClicked: full.openAbout()
            }

            MenuSeparator {}

            MenuRow {
                Layout.fillWidth: true
                iconName: "preferences-system"
                text: i18n("System Settings…")
                onClicked: full.run(() => full.plasmoidItem.launch("systemsettings"))
            }
            MenuRow {
                Layout.fillWidth: true
                iconName: "plasma-discover"
                text: i18n("App Store…")
                onClicked: full.run(() => full.plasmoidItem.launch("plasma-discover"))
            }

            MenuSeparator {}

            MenuRow {
                Layout.fillWidth: true
                iconName: "process-stop"
                text: i18n("Force Quit…")
                onClicked: full.run(() => full.plasmoidItem.launch("sh " + full.plasmoidItem.scriptPath("forcequit.sh")))
            }

            MenuSeparator {}

            MenuRow {
                Layout.fillWidth: true
                visible: full.plasmoidItem.itemVisible(full.plasmoidItem.suspendOk)
                enabled: full.plasmoidItem.itemEnabled(full.plasmoidItem.suspendOk)
                iconName: "system-suspend"
                text: i18n("Sleep")
                hint: full.plasmoidItem.itemHint(full.plasmoidItem.suspendOk)
                onClicked: full.run(() => full.plasmoidItem.sessionCall("suspend"))
            }
            MenuRow {
                Layout.fillWidth: true
                visible: full.plasmoidItem.itemVisible(full.plasmoidItem.hibernateOk)
                enabled: full.plasmoidItem.itemEnabled(full.plasmoidItem.hibernateOk)
                iconName: "system-suspend-hibernate"
                text: i18n("Hibernate")
                hint: full.plasmoidItem.itemHint(full.plasmoidItem.hibernateOk)
                onClicked: full.run(() => full.plasmoidItem.sessionCall("hibernate"))
            }

            MenuSeparator {}

            MenuRow {
                Layout.fillWidth: true
                visible: full.plasmoidItem.itemVisible(full.plasmoidItem.rebootOk)
                enabled: full.plasmoidItem.itemEnabled(full.plasmoidItem.rebootOk)
                iconName: "system-reboot"
                text: i18n("Restart…")
                hint: full.plasmoidItem.itemHint(full.plasmoidItem.rebootOk)
                // Plasma asks for confirmation itself (per the user's logout settings).
                onClicked: full.run(() => full.plasmoidItem.sessionCall("requestReboot"))
            }
            MenuRow {
                Layout.fillWidth: true
                visible: full.plasmoidItem.itemVisible(full.plasmoidItem.shutdownOk)
                enabled: full.plasmoidItem.itemEnabled(full.plasmoidItem.shutdownOk)
                iconName: "system-shutdown"
                text: i18n("Shut Down…")
                hint: full.plasmoidItem.itemHint(full.plasmoidItem.shutdownOk)
                onClicked: full.run(() => full.plasmoidItem.sessionCall("requestShutdown"))
            }

            MenuSeparator {}

            MenuRow {
                Layout.fillWidth: true
                iconName: "system-lock-screen"
                text: i18n("Lock Screen")
                onClicked: full.run(() => full.plasmoidItem.sessionCall("lock"))
            }
            MenuRow {
                Layout.fillWidth: true
                iconName: "system-log-out"
                text: i18n("Log Out…")
                onClicked: full.run(() => full.plasmoidItem.sessionCall("requestLogout"))
            }
        }
    }
}
