/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3

// Content of the "About This Computer" window.
FocusScope {
    id: page

    implicitWidth: Kirigami.Units.gridUnit * 26
    implicitHeight: Kirigami.Units.gridUnit * 26

    required property var info
    required property bool loading
    // {label, value} rows prepared by main.qml.
    required property var rows

    signal closeRequested()
    signal moreInfoRequested()

    Keys.onEscapePressed: closeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("About This Computer")
                elide: Text.ElideRight
            }

            PlasmaComponents3.ToolButton {
                focus: true
                icon.name: "window-close-symbolic"
                text: i18n("Close")
                display: PlasmaComponents3.AbstractButton.IconOnly
                Accessible.name: text
                onClicked: page.closeRequested()
                PlasmaComponents3.ToolTip.text: text
                PlasmaComponents3.ToolTip.visible: hovered
                PlasmaComponents3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        PlasmaComponents3.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                contentWidth: width
                contentHeight: body.implicitHeight
                clip: true

                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Kirigami.Units.largeSpacing
                        source: page.info.os_logo || "computer"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    }

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 2
                        text: page.info.os_pretty_name || i18n("About This Computer")
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }

                    PlasmaComponents3.BusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        visible: page.loading && page.rows.length === 0
                        running: visible
                    }

                    // Card with the information in two columns (label / value).
                    Rectangle {
                        Layout.fillWidth: true
                        visible: page.rows.length > 0
                        implicitHeight: grid.implicitHeight + Kirigami.Units.largeSpacing * 2
                        radius: Kirigami.Units.cornerRadius * 2
                        color: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.06)

                        GridLayout {
                            id: grid
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.largeSpacing
                            columns: 2
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: page.rows
                                delegate: PlasmaComponents3.Label {
                                    required property var modelData
                                    required property int index
                                    // Labels in column 0; values (second Repeater) in column 1, same row.
                                    Layout.row: index
                                    Layout.column: 0
                                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                    text: modelData.label
                                    opacity: 0.7
                                }
                            }
                            Repeater {
                                model: page.rows
                                delegate: PlasmaComponents3.Label {
                                    required property var modelData
                                    required property int index
                                    Layout.row: index
                                    Layout.column: 1
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                    }

                    PlasmaComponents3.Button {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Kirigami.Units.largeSpacing
                        // Icon names from the apps' own .desktop files, present in Breeze too.
                        icon.name: "hwinfo"
                        text: i18n("More Information…")
                        onClicked: page.moreInfoRequested()
                    }
                }
            }
        }
    }
}
