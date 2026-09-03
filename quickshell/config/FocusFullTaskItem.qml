import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Full task row for the FocusAppScreen (more buttons than hover variant).
Rectangle {
    id: root

    property var  task:      null
    property var  service:   null
    property bool isActive:  service && service.currentTask
                             && service.currentTask.id === task.id

    signal doneClicked()
    signal deleteClicked()
    signal playClicked()
    signal editClicked()

    implicitHeight: 44
    color: hArea.containsMouse ? Theme.bgHover : "transparent"
    radius: Theme.radiusSm

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 8

        // Circle checkbox — empty circle when pending, filled accent + checkmark when done
        Rectangle {
            width: 18; height: 18; radius: 9
            color: task && task.completed ? Theme.accent : "transparent"
            border.color: Theme.textSecondary
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 10; height: 10
                fillMode: Image.PreserveAspectFit
                visible: task && task.completed
            }

            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doneClicked() }
        }

        // Title
        Text {
            text: task ? task.title : ""
            font.pixelSize: Theme.fontMd
            color: task && task.completed ? Theme.textMuted : Theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Estimated mins badge
        Rectangle {
            visible: task && task.estimated_mins
            color: Theme.bgItem
            radius: Theme.radiusSm
            implicitWidth: minsLabel.implicitWidth + 10
            implicitHeight: 20

            Text {
                id: minsLabel
                anchors.centerIn: parent
                text: task ? String(task.estimated_mins) : ""
                font.pixelSize: Theme.fontSm
                color: Theme.textSecondary
            }
        }

        // Play / Pause button
        Rectangle {
            width: 28; height: 28; radius: 14
            color: isActive ? Qt.rgba(0.9, 0.22, 0.21, 0.15) : Theme.accent
            visible: !(task && task.completed)

            Image {
                anchors.centerIn: parent
                source: {
                    if (!isActive) return Theme.iconsPath + "play.svg"
                    return service.sessionPaused ? Theme.iconsPath + "play-accent.svg"
                                                 : Theme.iconsPath + "pause.svg"
                }
                width: 13; height: 13
                fillMode: Image.PreserveAspectFit
            }

            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playClicked() }
        }

        // Edit button
        Image {
            source: Theme.iconsPath + "pencil-square.svg"
            width: 15; height: 15
            fillMode: Image.PreserveAspectFit
            opacity: hArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editClicked() }
        }

        // Delete button
        Image {
            source: Theme.iconsPath + "trash.svg"
            width: 15; height: 15
            fillMode: Image.PreserveAspectFit
            opacity: hArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.deleteClicked() }
        }

    }

    MouseArea {
        id: hArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
