import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Drop-in widget for Bar.qml's right Row.
// Usage: FocusWidget { barWindow: root }
Item {
    id: root
    implicitWidth:  badge.implicitWidth
    implicitHeight: parent ? parent.height : 38

    property var barWindow: null

    // ── Service ───────────────────────────────────────────────────────────
    FocusService {
        id: svc
    }

    // ── Hover state ───────────────────────────────────────────────────────
    property bool badgeHovered: false
    property bool panelHovered: false
    readonly property bool showPanel: badgeHovered || panelHovered

    Timer {
        id: hideDelay
        interval: 180
        onTriggered: { hoverWin.visible = false }
    }

    onShowPanelChanged: {
        if (showPanel) {
            hideDelay.stop()
            hoverWin.visible = true
        } else {
            hideDelay.restart()
        }
    }

    // ── IPC — quickshell ipc call focus toggle ────────────────────────────
    IpcHandler {
        target: "focus"
        function toggle() { if (root.visible) appWin.visible = !appWin.visible }
    }

    // ── Badge (inline in bar) ─────────────────────────────────────────────
    FocusBarBadge {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        service: svc
        onHovered: function(h) { root.badgeHovered = h }
    }

    // ── Hover popup ───────────────────────────────────────────────────────
    PopupWindow {
        id: hoverWin
        anchor.window:          root.barWindow
        anchor.item:            root
        anchor.edges:           Edges.Bottom
        anchor.gravity:         Edges.Bottom
        anchor.margins.top:     4
        visible:                false
        implicitWidth:          hoverPanel.implicitWidth
        implicitHeight:         hoverPanel.implicitHeight
        color:                  "transparent"

        FocusHoverPanel {
            id: hoverPanel
            anchors.fill: parent
            service: svc

            onPanelHoveredChanged: function(h) { root.panelHovered = h }

            onExpand: {
                hoverWin.visible = false
                appWin.visible   = true
            }
        }
    }

    // ── Full app window (XDG toplevel — movível pelo compositor) ─────────
    FloatingWindow {
        id: appWin
        visible: false
        width:   720
        height:  480

        FocusAppScreen {
            id: appScreen
            anchors.fill: parent
            service: svc
            onCloseRequested: appWin.visible = false
        }
    }
}
