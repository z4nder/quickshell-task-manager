import QtQuick
import QtQuick.Controls
import Quickshell
import "components"

ShellRoot {
    // ── Service (shared state) ────────────────────────────────────────────
    FocusService {
        id: svc
        // Override if focusctl is not in PATH:
        // focusBin: "/home/user/.cargo/bin/focusctl"
    }

    // ── Hover / app visibility state ──────────────────────────────────────
    property bool badgeHovered:  false
    property bool panelHovered:  false
    property bool appVisible:    false

    // Delayed hide so moving mouse badge→panel doesn't flicker
    property bool showPanel: badgeHovered || panelHovered

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: { if (!shellRoot.showPanel) hoverWin.visible = false }
    }

    onShowPanelChanged: {
        if (showPanel) {
            hideTimer.stop()
            hoverWin.visible = true
        } else {
            hideTimer.restart()
        }
    }

    id: shellRoot

    // ── Badge panel window ────────────────────────────────────────────────
    PanelWindow {
        id: badgeWin
        anchors.top: true
        width: badge.implicitWidth + 4
        height: badge.implicitHeight + 4
        color: "transparent"

        BarBadge {
            id: badge
            anchors.centerIn: parent
            service: svc

            onHovered: function(h) { shellRoot.badgeHovered = h }
        }
    }

    // ── Hover panel floating window ───────────────────────────────────────
    FloatingWindow {
        id: hoverWin
        visible: false
        width:  hoverPanel.implicitWidth
        height: hoverPanel.implicitHeight
        color:  "transparent"

        // Position below the badge
        x: (Screen.width  - width)  / 2
        y: badgeWin.height + 4

        HoverPanel {
            id: hoverPanel
            anchors.fill: parent
            service: svc

            onPanelHoveredChanged: function(h) { shellRoot.panelHovered = h }

            onExpand: {
                hoverWin.visible = false
                appWin.visible   = true
                shellRoot.appVisible = true
            }
        }
    }

    // ── Full app floating window ──────────────────────────────────────────
    FloatingWindow {
        id: appWin
        visible: false
        width:  appScreen.implicitWidth
        height: appScreen.implicitHeight
        color:  "transparent"

        // Centered on screen
        x: (Screen.width  - width)  / 2
        y: (Screen.height - height) / 2

        AppScreen {
            id: appScreen
            anchors.fill: parent
            service: svc

            onCloseRequested: {
                appWin.visible = false
                shellRoot.appVisible = false
            }
        }

        // Click outside closes
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.4) }

        Keys.onEscapePressed: {
            appWin.visible = false
            shellRoot.appVisible = false
        }
    }
}
