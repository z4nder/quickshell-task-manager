import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

// Compact task row for the hover panel.
Rectangle {
    id: root

    property var    task:    null
    property var    service: null
    property bool   isActive: service && service.currentTask
                              && service.currentTask.id === task.id

    signal playClicked()
    signal doneClicked()

    implicitHeight: 36
    color: hoverArea.containsMouse ? Theme.bgHover : "transparent"
    radius: Theme.radiusSm

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 8

        // Circle checkbox
        Rectangle {
            width: 16; height: 16
            radius: 8
            color: "transparent"
            border { color: Theme.textSecondary; width: 1.5 }

            // checkmark when completed
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                color: Theme.accent
                visible: task && task.completed
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.doneClicked()
            }
        }

        // Title
        Text {
            text: task ? task.title : ""
            font.pixelSize: Theme.fontMd
            color: Theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Estimated mins badge
        Row {
            spacing: 3
            visible: task && task.estimated_mins
            Text {
                text: task ? String(task.estimated_mins) : ""
                font.pixelSize: Theme.fontSm
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "min"
                font.pixelSize: Theme.fontSm - 1
                color: Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Play / pause button
        Rectangle {
            width: 26; height: 26
            radius: 13
            color: isActive ? Qt.rgba(0.9, 0.22, 0.21, 0.2) : Theme.accent

            Text {
                anchors.centerIn: parent
                text: {
                    if (!isActive) return "▶"
                    return service.sessionPaused ? "▶" : "⏸"
                }
                font.pixelSize: isActive ? 11 : 10
                color: isActive ? Theme.accent : Theme.textPrimary
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.playClicked()
            }
        }

        // Drag handle dots
        Column {
            spacing: 2
            Repeater {
                model: 3
                Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.textMuted }
            }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
