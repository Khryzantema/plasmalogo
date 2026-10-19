/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// One menu entry, like in the Apple menu: icon + text, highlighted with a
// rounded rectangle in the theme's accent color on hover or keyboard focus.
T.AbstractButton {
    id: row

    property string iconName
    // Short text on the right (e.g. "Unavailable").
    property string hint

    readonly property bool highlighted: enabled && (hovered || visualFocus)

    implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.6, content.implicitHeight + Kirigami.Units.smallSpacing * 2)
    implicitWidth: content.implicitWidth + leftPadding + rightPadding
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing

    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    Accessible.role: Accessible.MenuItem
    Accessible.name: text
    Accessible.description: hint

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            row.clicked();
            event.accepted = true;
        }
    }
    // Like a real menu, the pointer moves the selection: the hovered entry takes
    // the keyboard focus (without a focus ring), so only one entry is lit and
    // the arrow keys continue from there.
    onHoveredChanged: {
        if (hovered && enabled) {
            forceActiveFocus(Qt.MouseFocusReason);
        }
    }
    // Up/down arrows walk through the entries, like in a real menu.
    Keys.onUpPressed: nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
    Keys.onDownPressed: nextItemInFocusChain(true).forceActiveFocus(Qt.TabFocusReason)

    background: Rectangle {
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: row.highlighted ? (row.down ? 0.85 : 1) : 0
    }

    contentItem: RowLayout {
        id: content
        spacing: Kirigami.Units.largeSpacing
        opacity: row.enabled ? 1 : 0.5

        Kirigami.Icon {
            source: row.iconName
            color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: row.text
            color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        PlasmaComponents3.Label {
            visible: text.length > 0
            text: row.hint
            font: Kirigami.Theme.smallFont
            color: row.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
        }
    }
}
