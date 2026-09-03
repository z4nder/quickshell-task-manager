import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

// Full task row for the AppScreen (more buttons than hover variant).
Rectangle {
    id: root

    property var  task:      null
    property var  service:   null
    property bool isActive:  service && service.currentTask
                             && service.currentTask.id === task.id

    signal doneClicked()
    signal deleteClicked()
    signal playClicked()

    implicitHeight: 44
    color: hArea.containsMouse ? Theme.bgHover : "transparent"
    radius: Theme.radiusSm

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 8

        // Circle checkbox
        Rectangle {
            width: 18; height: 18; radius: 9
            color: "transparent"
            border { color: task && task.completed ? Theme.accent : Theme.textSecondary; width: 1.5 }

            Text {
                anchors.centerIn: parent
                text: "✓"; font.pixelSize: 10
                color: Theme.accent
                visible: task && task.completed
            }

            MouseArea { anchors.fill: parent; onClicked: root.doneClicked() }
        }

        // Title
        Text {
            text: task ? task.title : ""
            font.pixelSize: Theme.fontMd
            color: task && task.completed ? Theme.textMuted : Theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Date badge
        Rectangle {
            visible: task && task.scheduled_date
            color: Theme.bgItem
            radius: Theme.radiusSm
            implicitWidth: dateLabel.implicitWidth + 10
            implicitHeight: 20

            Text {
                id: dateLabel
                anchors.centerIn: parent
                text: {
                    if (!task || !task.scheduled_date) return ""
                    // Show "Today" if matches today's date
                    var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                    if (task.scheduled_date === today) return "Today"
                    return task.scheduled_date.substring(5) // MM-DD
                }
                font.pixelSize: Theme.fontSm
                color: Theme.textSecondary
            }
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

            Text {
                anchors.centerIn: parent
                text: {
                    if (!isActive) return "▶"
                    return service.sessionPaused ? "▶" : "⏸"
                }
                font.pixelSize: 11
                color: isActive ? Theme.accent : Theme.textPrimary
            }

            MouseArea { anchors.fill: parent; onClicked: root.playClicked() }
        }

        // Delete button
        Text {
            text: "🗑"
            font.pixelSize: Theme.fontMd
            color: Theme.textMuted
            opacity: hArea.containsMouse ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea { anchors.fill: parent; onClicked: root.deleteClicked() }
        }

        // Drag handle
        Column {
            spacing: 2
            opacity: hArea.containsMouse ? 1 : 0.3
            Repeater {
                model: 3
                Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.textMuted }
            }
        }
    }

    MouseArea {
        id: hArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
