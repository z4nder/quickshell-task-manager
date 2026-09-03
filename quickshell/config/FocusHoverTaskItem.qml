import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

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

        // Check toggle — empty circle when pending, filled accent + checkmark when done
        Rectangle {
            width: 16; height: 16; radius: 8
            color: task && task.completed ? Theme.accent : "transparent"
            border.color: Theme.textSecondary
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 9; height: 9
                fillMode: Image.PreserveAspectFit
                visible: task && task.completed
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
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
            visible: !(task && task.completed)

            Image {
                anchors.centerIn: parent
                source: {
                    if (!isActive) return Theme.iconsPath + "play.svg"
                    return service.sessionPaused ? Theme.iconsPath + "play-accent.svg"
                                                 : Theme.iconsPath + "pause.svg"
                }
                width: 12; height: 12
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playClicked()
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
