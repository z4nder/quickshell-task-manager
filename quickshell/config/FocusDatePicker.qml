import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Date picker: display field + inline calendar dropdown.
// Exposes `value` (string "YYYY-MM-DD" or "").
Item {
    id: root

    property string value:       ""
    property string placeholder: "YYYY-MM-DD"
    property var    service:     null

    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
    }

    implicitHeight: 36
    implicitWidth:  200

    property bool _open: false

    function _parseDate() {
        var m = root.value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
        if (m) return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
        return new Date()
    }

    // ── Field row ───────────────────────────────────────────────────────────
    Rectangle {
        id: fieldRect
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 36
        radius: Theme.radiusSm
        color: _theme.bgItem
        border.color: root._open ? _theme.accent : (fieldArea.containsMouse ? _theme.accent : _theme.border)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 100 } }

        MouseArea {
            id: fieldArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._open = !root._open
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
            spacing: 6
            // pass mouse events through to fieldArea
            enabled: false

            Text {
                Layout.fillWidth: true
                text: root.value !== "" ? root.value : root.placeholder
                font.pixelSize: Theme.fontMd
                color: root.value !== "" ? _theme.textPrimary : _theme.textMuted
                verticalAlignment: Text.AlignVCenter
            }

            Image {
                width: 14; height: 14
                source: Theme.iconsPath + "calendar.svg"
                fillMode: Image.PreserveAspectFit
                opacity: fieldArea.containsMouse || root._open ? 1.0 : 0.5
            }
        }
    }

    // ── Calendar dropdown ────────────────────────────────────────────────────
    Rectangle {
        id: calDrop
        anchors { left: parent.left; top: fieldRect.bottom; topMargin: 4 }
        width:   242
        height:  inlineCal.implicitHeight + 24
        radius:  Theme.radiusMd
        color:   _theme.bgPanel
        border.color: _theme.accent
        border.width: 1
        visible: root._open
        z: 999

        FocusMonthCalendar {
            id: inlineCal
            anchors { fill: parent; margins: 12 }
            service: root.service
            selectedDate: root._parseDate()
            onDateSelected: function(d) {
                root.value = Qt.formatDate(d, "yyyy-MM-dd")
                root._open = false
            }
        }
    }

    // Close when clicking outside
    MouseArea {
        anchors.fill: parent
        anchors.margins: -9999
        z: root._open ? 998 : -1
        enabled: root._open
        onClicked: root._open = false
    }
}
