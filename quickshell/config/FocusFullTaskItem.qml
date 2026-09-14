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

    // Optimistic done state: show check immediately, send command after delay
    property bool _pendingDone: false

    signal doneClicked()
    signal deleteClicked()
    signal playClicked()
    signal editClicked()

    // Fires the actual backend command after 1s
    Timer {
        id: doneTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root._pendingDone = false
            root.doneClicked()
        }
    }

    implicitHeight: 44
    radius: Theme.radiusSm
    color: (isActive || hArea.containsMouse) ? Theme.bgHover : "transparent"

    // Active left-edge accent bar
    Rectangle {
        width: 3
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
        radius: 2
        color: Theme.accent
        visible: isActive
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
        spacing: 8

        // Circle checkbox — empty circle when pending, filled accent + checkmark when done
        Rectangle {
            width: 22; height: 22; radius: 11
            color: (task && task.completed) || root._pendingDone ? Theme.accent : "transparent"
            border.color: Theme.textSecondary
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 12; height: 12
                fillMode: Image.PreserveAspectFit
                visible: (task && task.completed) || root._pendingDone
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (task && task.completed) {
                        root.doneClicked()
                    } else if (!root._pendingDone) {
                        root._pendingDone = true
                        doneTimer.start()
                    } else {
                        doneTimer.stop()
                        root._pendingDone = false
                    }
                }
            }
        }

        // Title — click selects/starts this task
        Text {
            text: task ? task.title : ""
            font.pixelSize: Theme.fontMd
            color: (task && task.completed) || root._pendingDone ? Theme.textMuted : Theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !(task && task.completed) && !root._pendingDone
                onClicked: {
                    if (service && task) service.startSession(task.id)
                }
            }
        }

        // Estimated mins badge
        Rectangle {
            visible: task && task.estimated_mins
            color: isActive ? Qt.rgba(0.9, 0.22, 0.21, 0.2) : Theme.bgItem
            radius: Theme.radiusSm
            implicitWidth: minsLabel.implicitWidth + 10
            implicitHeight: 20

            Text {
                id: minsLabel
                anchors.centerIn: parent
                text: task ? String(task.estimated_mins) : ""
                font.pixelSize: Theme.fontSm
                color: isActive ? Theme.textPrimary : Theme.textSecondary
            }
        }

        // Play / Pause button
        Rectangle {
            width: 28; height: 28; radius: 14
            color: isActive ? Qt.rgba(0.9, 0.22, 0.21, 0.25) : Theme.accent
            visible: !(task && task.completed) && !root._pendingDone

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
