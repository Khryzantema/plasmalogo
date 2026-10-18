/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

// "General" settings page: panel icon, icon size and unavailable actions.
Kirigami.FormLayout {
    id: page

    // Plain properties (not aliases): Plasma's config loader initializes and
    // saves any "cfg_*" property that has a NOTIFY signal.
    property string cfg_panelIconName: "start-here-kde"
    property int cfg_panelIconSize: 32
    property alias cfg_hideUnsupportedActions: hideUnsupportedCheck.checked

    RowLayout {
        Kirigami.FormData.label: i18n("Panel icon:")
        spacing: Kirigami.Units.smallSpacing

        Button {
            icon.name: page.cfg_panelIconName.length > 0 ? page.cfg_panelIconName : "start-here-kde"
            text: i18n("Choose Icon…")
            onClicked: iconDialog.open()
        }

        Button {
            text: i18n("Default")
            onClicked: page.cfg_panelIconName = "start-here-kde"
        }
    }

    // The same icon picker as Kickoff and other Plasma widgets, with search and
    // categories, instead of a fixed list of icon names.
    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: page.cfg_panelIconName = iconName || "start-here-kde"
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon size:")
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: page.cfg_panelIconName.length > 0 ? page.cfg_panelIconName : "start-here-kde"
            Layout.preferredWidth: page.cfg_panelIconSize
            Layout.preferredHeight: page.cfg_panelIconSize
        }

        Slider {
            id: iconSizeSlider
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            from: 16
            to: 64
            stepSize: 1
            snapMode: Slider.SnapAlways
            value: page.cfg_panelIconSize
            onMoved: page.cfg_panelIconSize = Math.round(value)
        }

        Label {
            text: i18n("%1 px", page.cfg_panelIconSize)
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
        }
    }

    CheckBox {
        id: hideUnsupportedCheck
        Kirigami.FormData.label: i18n("Unavailable actions:")
        text: i18n("Hide them instead of showing them disabled")
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: true
        type: Kirigami.MessageType.Information
        text: i18n("Items such as Hibernate or Sleep only appear if the computer actually supports the action.")
    }
}
