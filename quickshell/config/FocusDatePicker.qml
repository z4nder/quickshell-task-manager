import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "FocusTheme.js" as Theme

// Date picker: text field + calendar popup.
// Exposes `value` (string "YYYY-MM-DD" or "").
Rectangle {
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
    radius: Theme.radiusSm
    color: _theme.bgItem
    border.color: (dateField.activeFocus || calPopup.visible) ? _theme.accent : _theme.border
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: 100 } }

    // Parse value string to a JS Date (falls back to today)
    function _parseDate() {
        var m = root.value.match(/^(\d{4})-(\d{2})-(\d{2})$/)
        if (m) return new Date(parseInt(m[1]), parseInt(m[2]) - 1, parseInt(m[3]))
        return new Date()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
        spacing: 4

        TextField {
            id: dateField
            Layout.fillWidth: true
            text: root.value
            placeholderText: root.placeholder
            placeholderTextColor: _theme.textMuted
            color: _theme.textPrimary
            font.pixelSize: Theme.fontMd
            selectByMouse: true
            readOnly: true
            onPressed: calPopup.visible ? calPopup.close() : calPopup.open()
            background: Item {}    // styled by parent Rectangle
        }

        // Calendar toggle button
        Rectangle {
            width: 26; height: 26
            radius: Theme.radiusSm
            color: calBtnArea.containsMouse ? _theme.bgHover : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "calendar.svg"
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
                opacity: calBtnArea.containsMouse || calPopup.visible ? 1.0 : 0.6
            }

            MouseArea {
                id: calBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calPopup.visible ? calPopup.close() : calPopup.open()
            }
        }
    }

    Popup {
        id: calPopup
        y: root.height + 6
        x: Math.min(0, root.width - width)   // don't overflow right edge
        width:   230
        padding: 12
        modal:   false
        focus:   false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color:        root._theme.bgPanel
            radius:       Theme.radiusMd
            border.color: root._theme.border
            border.width: 1

            layer.enabled: true
            layer.effect: null
        }

        // Drop shadow via wrapper
        Rectangle {
            anchors { fill: parent; margins: -1 }
            radius: Theme.radiusMd + 1
            color: "transparent"
            border.color: Qt.rgba(0, 0, 0, 0.4)
            border.width: 1
            z: -1
        }

        FocusMonthCalendar {
            id: inlineCal
            width:   calPopup.width - calPopup.padding * 2
            height:  implicitHeight
            service: root.service

            selectedDate: root._parseDate()

            onDateSelected: function(d) {
                root.value = Qt.formatDate(d, "yyyy-MM-dd")
                calPopup.close()
            }
        }

        // size popup to calendar content
        height: inlineCal.height + calPopup.padding * 2
    }
}
