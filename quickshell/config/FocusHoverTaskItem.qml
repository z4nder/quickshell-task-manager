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

    // Optimistic done state: show check immediately, send command after delay
    property bool _pendingDone: false

    signal playClicked()
    signal doneClicked()

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

    implicitHeight: 36
    color: (isActive || hoverArea.containsMouse) ? Theme.bgHover : "transparent"
    radius: Theme.radiusSm

    // Active left-edge accent bar
    Rectangle {
        width: 3
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 5; bottomMargin: 5 }
        radius: 2
        color: Theme.accent
        visible: isActive
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 8

        // Check toggle — empty circle when pending, filled accent + checkmark when done
        Rectangle {
            width: 20; height: 20; radius: 10
            color: (task && task.completed) || root._pendingDone ? Theme.accent : "transparent"
            border.color: Theme.textSecondary
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 11; height: 11
                fillMode: Image.PreserveAspectFit
                visible: (task && task.completed) || root._pendingDone
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (task && task.completed) {
                        // Undone: no delay, act immediately
                        root.doneClicked()
                    } else if (!root._pendingDone) {
                        root._pendingDone = true
                        doneTimer.start()
                    } else {
                        // Second click cancels pending done
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
            color: Theme.textPrimary
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
            visible: !(task && task.completed) && !root._pendingDone

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
