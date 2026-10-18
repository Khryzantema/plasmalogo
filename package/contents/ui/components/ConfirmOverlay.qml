/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// Confirmation question floating over the popup content. It lives inside the
// popup (no separate dialog window) and does not change the popup size:
// resizing the popup window makes Plasma move it, which flickers on Wayland.
Item {
    id: overlay

    property bool open: false
    property string title
    property string text
    property string iconName
    property string acceptText
    property var action: null

    signal dismissed()

    anchors.fill: parent
    visible: open || hideAnimation.running
    z: 100

    function ask(newTitle, newText, newIcon, newAcceptText, newAction) {
        title = newTitle;
        text = newText;
        iconName = newIcon;
        acceptText = newAcceptText;
        action = newAction;
        open = true;
    }

    function accept() {
        const run = action;
        open = false;
        run?.();
    }

    onOpenChanged: {
        if (open) {
            hideAnimation.stop();
            showAnimation.restart();
            Qt.callLater(() => cancelButton.forceActiveFocus(Qt.TabFocusReason));
        } else {
            showAnimation.stop();
            hideAnimation.restart();
        }
    }

    Keys.onEscapePressed: open = false

    // Dims the content behind; clicking it cancels.
    Rectangle {
        id: scrim
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: overlay.open = false
            onWheel: wheel => wheel.accepted = true
        }
    }

    Kirigami.ShadowedRectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.smallSpacing * 2
        height: column.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.cornerRadius * 2
        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)
        shadow.size: Kirigami.Units.gridUnit
        shadow.color: Qt.rgba(0, 0, 0, 0.35)
        shadow.yOffset: 2

        // Keeps clicks on the card from reaching the scrim.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                source: overlay.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: overlay.title
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                text: overlay.text
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                opacity: 0.85
            }

            // Stacked: the popup is as narrow as the menu, so they do not fit side by side.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: overlay.acceptText
                    onClicked: overlay.accept()
                }
                PlasmaComponents3.Button {
                    id: cancelButton
                    Layout.fillWidth: true
                    text: i18n("Cancel")
                    onClicked: overlay.open = false
                }
            }
        }
    }

    // Kirigami durations follow the system animation speed (0 when animations are off).
    ParallelAnimation {
        id: showAnimation
        NumberAnimation { target: scrim; property: "opacity"; from: 0; to: 0.6; duration: Kirigami.Units.longDuration }
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; from: 0.92; to: 1; duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: hideAnimation
        NumberAnimation { target: scrim; property: "opacity"; to: 0; duration: Kirigami.Units.shortDuration }
        NumberAnimation { target: card; property: "opacity"; to: 0; duration: Kirigami.Units.shortDuration; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "scale"; to: 0.95; duration: Kirigami.Units.shortDuration; easing.type: Easing.InCubic }
    }
}
