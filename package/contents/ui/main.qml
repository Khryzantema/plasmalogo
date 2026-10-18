/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support

// Applet root: the panel button, the session actions with their logind
// fallback, and the system information shown in "About This Computer".
PlasmoidItem {
    id: root

    Plasmoid.icon: plasmoid.configuration.panelIconName

    preferredRepresentation: compactRepresentation
    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 12

    toolTipMainText: Plasmoid.title
    toolTipSubText: info.os_pretty_name || ""

    // --- Session backend (sleep, hibernate, restart, shut down, lock, log out) ---
    // Loaded through a Loader so a failing import does not break the whole widget.
    Loader {
        id: sessionLoader
        source: "SessionBackend.qml"
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("PlasmaLogo: org.kde.plasma.private.sessions is unavailable; using only the logind fallback.")
            }
        }
    }
    readonly property var session: sessionLoader.item

    function sessionCan(propName) {
        return root.session ? root.session[propName] : undefined
    }

    function sessionCall(methodName) {
        try {
            if (root.session && typeof root.session[methodName] === "function") {
                root.session[methodName]()
                return true
            }
        } catch (e) {
            console.warn("PlasmaLogo: session." + methodName + "() failed: " + e)
        }
        notify(i18n("Could not perform this action (the Plasma session API is unavailable or failed)."))
        return false
    }

    // --- Fallback: capabilities from systemd-logind (DBus), refreshed each time the popup opens ---
    property var logindCaps: ({ "suspend": "", "hibernate": "", "reboot": "", "poweroff": "" })

    function isSupported(sessionValue, logindValue) {
        if (sessionValue === true) return true
        if (logindValue === "yes" || logindValue === "challenge") return true
        if (sessionValue === false) return false
        if (logindValue === "no" || logindValue === "na") return false
        return true // nothing known for sure: do not hide
    }

    readonly property bool suspendOk: isSupported(sessionCan("canSuspend"), logindCaps.suspend)
    readonly property bool hibernateOk: isSupported(sessionCan("canHibernate"), logindCaps.hibernate)
    readonly property bool rebootOk: isSupported(sessionCan("canReboot"), logindCaps.reboot)
    readonly property bool shutdownOk: isSupported(sessionCan("canShutdown"), logindCaps.poweroff)

    function itemVisible(ok) {
        return plasmoid.configuration.hideUnsupportedActions ? ok : true
    }
    function itemEnabled(ok) {
        return plasmoid.configuration.hideUnsupportedActions ? true : ok
    }
    function itemHint(ok) {
        return ok ? "" : i18n("Unavailable on this computer")
    }

    // --- External commands (launching apps, Force Quit, logind checks), all asynchronous ---
    function scriptPath(name) {
        return Qt.resolvedUrl("../scripts/" + name).toString().replace(/^file:\/\//, "")
    }

    Plasma5Support.DataSource {
        id: launchSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName)
        }
        function run(cmd) {
            connectSource(cmd)
        }
    }

    Plasma5Support.DataSource {
        id: capsSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName)
            try {
                root.logindCaps = JSON.parse(data["stdout"])
            } catch (e) {
                console.warn("PlasmaLogo: unexpected output from syscaps.sh: " + e)
            }
        }
    }

    function refreshCaps() {
        // The "executable" engine runs the string through a shell, so calling
        // "sh <script>" works without relying on the executable bit.
        capsSource.connectSource("sh " + scriptPath("syscaps.sh"))
    }

    function launch(cmd) {
        launchSource.run("setsid " + cmd + " >/dev/null 2>&1 &")
    }

    function notify(text) {
        var escaped = String(text).replace(/'/g, "'\\''")
        var appName = Plasmoid.title.replace(/'/g, "'\\''")
        launchSource.run("command -v notify-send >/dev/null 2>&1 && notify-send -a '" + appName + "' '" + appName + "' '" + escaped + "'")
    }

    // --- System information (for "About This Computer") ---
    property var info: ({})
    property bool infoLoading: false

    Plasma5Support.DataSource {
        id: infoSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            disconnectSource(sourceName)
            root.infoLoading = false
            try {
                root.info = JSON.parse(data["stdout"])
            } catch (e) {
                console.warn("PlasmaLogo: unexpected output from sysinfo.sh: " + e)
            }
        }
    }

    function refreshInfo() {
        infoLoading = true
        infoSource.connectSource("sh " + scriptPath("sysinfo.sh"))
    }

    Component.onCompleted: {
        refreshInfo()
        refreshCaps()
    }

    function isGenericDmi(value) {
        if (!value) return true
        var v = value.trim().toLowerCase()
        if (v.length === 0) return true
        var placeholders = ["to be filled by o.e.m.", "system product name", "default string",
            "not specified", "o.e.m", "unknown", "none"]
        return placeholders.indexOf(v) !== -1
    }

    // "df -h" uses short suffixes ("201G", "1.8T"); show them as "201 GB", "1.8 TB".
    function diskSize(value) {
        var m = String(value).trim().match(/^([0-9.,]+)\s*([KMGTPE])i?B?$/i)
        if (!m) return value
        var number = Number(m[1].replace(",", "."))
        var text = isNaN(number) ? m[1] : number.toLocaleString(Qt.locale(), "f", Number.isInteger(number) ? 0 : 1)
        return text + " " + m[2].toUpperCase() + "B"
    }

    // Uptime text built from seconds, so that it can be translated.
    function formatUptime(seconds) {
        var days = Math.floor(seconds / 86400)
        var hours = Math.floor((seconds % 86400) / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        var parts = []
        if (days > 0) parts.push(i18np("%1 day", "%1 days", days))
        if (hours > 0) parts.push(i18np("%1 hour", "%1 hours", hours))
        if (minutes > 0 && days === 0) parts.push(i18np("%1 minute", "%1 minutes", minutes))
        return parts.length > 0 ? parts.join(", ") : i18n("less than a minute")
    }

    readonly property var infoRows: {
        var out = []
        var i = info

        if (i.os_pretty_name) out.push({ label: i18n("System"), value: i.os_pretty_name })
        if (i.plasma_version) out.push({ label: i18n("Plasma"), value: i.plasma_version })
        if (i.kernel) out.push({ label: i18n("Kernel"), value: i.kernel })

        var modelParts = []
        if (i.sys_vendor && !isGenericDmi(i.sys_vendor)) modelParts.push(i.sys_vendor)
        if (i.product_name && !isGenericDmi(i.product_name)) modelParts.push(i.product_name)
        if (Object.keys(i).length > 0) {
            out.push({ label: i18n("Model"), value: modelParts.length > 0 ? modelParts.join(" ") : i18n("Unidentified") })
        }

        if (i.cpu_model) {
            var cpuExtra = []
            if (i.cpu_cores) cpuExtra.push(i18np("%1 core", "%1 cores", Number(i.cpu_cores)))
            if (i.cpu_threads) cpuExtra.push(i18np("%1 thread", "%1 threads", Number(i.cpu_threads)))
            out.push({ label: i18n("Processor"), value: i.cpu_model + (cpuExtra.length ? " (" + cpuExtra.join(" / ") + ")" : "") })
        }
        if (i.mem_total_gb) out.push({ label: i18n("Memory"), value: i18n("%1 GB", i.mem_total_gb) })
        if (i.gpu) out.push({ label: i18n("Graphics"), value: i.gpu })
        if (i.disk_used && i.disk_total) out.push({ label: i18n("Storage"), value: i18n("%1 used of %2", diskSize(i.disk_used), diskSize(i.disk_total)) })
        if (i.hostname) out.push({ label: i18n("Computer Name"), value: i.hostname })
        if (i.uptime_seconds || i.uptime) out.push({ label: i18n("Uptime"), value: i.uptime_seconds ? formatUptime(Number(i.uptime_seconds)) : i.uptime })

        return out
    }

    // --- Panel button ---
    // The icon is drawn directly (no ToolButton): a ToolButton limits the icon
    // to the button size minus its padding, so the size setting barely mattered.
    compactRepresentation: MouseArea {
        id: panelButton

        Layout.minimumWidth: plasmoid.configuration.panelIconSize
        Layout.minimumHeight: plasmoid.configuration.panelIconSize
        Layout.preferredWidth: plasmoid.configuration.panelIconSize
        Layout.preferredHeight: plasmoid.configuration.panelIconSize

        hoverEnabled: true
        activeFocusOnTab: true

        property bool wasExpanded: false
        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.expanded = !root.expanded
                event.accepted = true
            }
        }

        Accessible.role: Accessible.Button
        Accessible.name: Plasmoid.title

        Kirigami.Icon {
            anchors.centerIn: parent
            // Follows the configured size, limited only by the actual panel thickness.
            width: Math.min(plasmoid.configuration.panelIconSize, Math.max(parent.width, parent.height))
            height: width
            source: plasmoid.configuration.panelIconName
            active: panelButton.containsMouse || root.expanded
        }
    }

    // "About This Computer": window in the center of the screen, created on first use.
    Loader {
        id: aboutLoader
        active: false
        sourceComponent: AboutDialog {
            plasmoidItem: root
        }
        onLoaded: item.open()
    }

    function openAbout() {
        if (aboutLoader.item) {
            aboutLoader.item.open()
        } else {
            aboutLoader.active = true
        }
    }

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }
}
