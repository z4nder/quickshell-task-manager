import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Theme.js" as Theme

// Popup that appears on badge hover.
// Two columns: To Do list | Activity heatmap.
Rectangle {
    id: root

    property var service: null
    signal expand()
    signal panelHoveredChanged(bool h)

    implicitWidth:  360
    implicitHeight: 220
    color:          Theme.bgPanel
    radius:         Theme.radiusLg

    // shadow effect
    layer.enabled: true
    layer.effect: null  // add DropShadow if QtGraphicalEffects available

    RowLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 16

        // ── To Do column ─────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Header row
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "To Do"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
                // Sort / expand button
                Row {
                    spacing: 6

                    // Sort icon (placeholder)
                    Text {
                        text: "⇅"
                        font.pixelSize: Theme.fontMd
                        color: Theme.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // sort by estimated_mins desc — handled by proxy model
                                // for now, just trigger refresh
                                service.refreshTasks()
                            }
                        }
                    }

                    // Expand to full app
                    Text {
                        text: "⤢"
                        font.pixelSize: Theme.fontMd
                        color: Theme.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.expand()
                        }
                    }
                }
            }

            // Task list (max 4 visible, scrollable)
            ListView {
                id: todoList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2

                model: {
                    if (!service) return []
                    return service.tasks.filter(function(t) { return !t.completed })
                }

                delegate: HoverTaskItem {
                    width: todoList.width
                    task:    modelData
                    service: root.service

                    onPlayClicked: {
                        if (!service) return
                        if (service.sessionActive && service.currentTask
                                && service.currentTask.id === task.id) {
                            if (service.sessionPaused) service.resumeSession()
                            else                       service.pauseSession()
                        } else {
                            service.startSession(task.id)
                        }
                    }

                    onDoneClicked: {
                        if (service) service.doneTask(task.id)
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }

            // Add task input
            TextField {
                id: addField
                Layout.fillWidth: true
                placeholderText: "Add a task"
                color: Theme.textPrimary
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontSm
                background: Rectangle {
                    color: Theme.bgItem
                    radius: Theme.radiusSm
                }
                leftPadding: 8

                Keys.onReturnPressed: {
                    if (text.trim() !== "" && service) {
                        service.addTask(text.trim(), null)
                        text = ""
                    }
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────
        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        // ── Activity heatmap ──────────────────────────────────────────────
        ActivityHeatmap {
            service: root.service
            Layout.alignment: Qt.AlignTop
        }
    }

    // ── Hover tracking (so parent knows when mouse is over panel) ─────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.panelHoveredChanged(true)
        onExited:  root.panelHoveredChanged(false)
    }
}
