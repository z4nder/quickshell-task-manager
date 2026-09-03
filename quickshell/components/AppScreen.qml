import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Theme.js" as Theme

// Full app window: calendar on left, day/unscheduled tasks on right.
Rectangle {
    id: root

    property var  service:      null
    property date selectedDate: new Date()
    signal closeRequested()

    implicitWidth:  640
    implicitHeight: 420
    color:          Theme.bgPanel
    radius:         Theme.radiusLg

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left panel: Tasks header + Calendar + Today button ────────────
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.2)
            radius: Theme.radiusLg

            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Tasks"
                        font.pixelSize: Theme.fontXl
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "⚙"
                        font.pixelSize: Theme.fontMd
                        color: Theme.textSecondary
                    }
                }

                // Calendar
                MonthCalendar {
                    id: cal
                    service: root.service
                    selectedDate: root.selectedDate
                    Layout.fillWidth: true

                    onDateSelected: function(d) {
                        root.selectedDate = d
                    }
                }

                Item { Layout.fillHeight: true }

                // Today button
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    color: Theme.bgItem
                    radius: Theme.radiusSm

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        font.pixelSize: Theme.fontMd
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selectedDate = new Date()
                            cal.viewYear  = root.selectedDate.getFullYear()
                            cal.viewMonth = root.selectedDate.getMonth()
                        }
                    }
                }
            }
        }

        // ── Right panel: Day/Unscheduled tabs + task list ─────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Tab bar
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 0

                // "Today" label showing selected date
                Text {
                    text: {
                        var today = new Date()
                        if (Qt.formatDate(root.selectedDate, "yyyy-MM-dd")
                                === Qt.formatDate(today, "yyyy-MM-dd"))
                            return "Today"
                        return Qt.formatDate(root.selectedDate, "d MMM")
                    }
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Tabs
                Row {
                    spacing: 2
                    property int currentTab: 0

                    Repeater {
                        model: ["Day", "Unscheduled"]
                        delegate: Rectangle {
                            implicitWidth:  tabLabel.implicitWidth + 16
                            implicitHeight: 28
                            radius: Theme.radiusSm
                            color: parent.currentTab === index ? Theme.bgItem : "transparent"

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSm
                                color: parent.parent.currentTab === index
                                       ? Theme.textPrimary : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: parent.parent.currentTab = index
                            }
                        }
                    }

                    // expose currentTab to outer scope
                    id: tabRow
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 16
                height: 1
                color: Theme.border
            }

            // Task list
            ListView {
                id: taskList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: 6
                clip: true
                spacing: 2

                model: {
                    if (!service) return []
                    if (tabRow.currentTab === 0) {
                        // Day tab: tasks scheduled for selected date
                        return service.tasksForDate(root.selectedDate)
                    } else {
                        // Unscheduled tab
                        return service.unscheduledTasks()
                    }
                }

                delegate: FullTaskItem {
                    width: taskList.width
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

                    onDoneClicked:   { if (service) service.doneTask(task.id) }
                    onDeleteClicked: { if (service) service.deleteTask(task.id) }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16; Layout.rightMargin: 16
                height: 1
                color: Theme.border
            }

            // Add task input
            TextField {
                id: addTaskField
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 12
                Layout.topMargin: 6
                placeholderText: "Add a task"
                color: Theme.textPrimary
                placeholderTextColor: Theme.textMuted
                font.pixelSize: Theme.fontMd
                background: Rectangle { color: "transparent" }

                Keys.onReturnPressed: {
                    var title = text.trim()
                    if (title === "" || !service) return

                    if (tabRow.currentTab === 0) {
                        // Scheduled for the selected date
                        var iso = Qt.formatDate(root.selectedDate, "yyyy-MM-dd")
                        service.addTask(title, iso)
                    } else {
                        // Unscheduled
                        service.addTask(title, null)
                    }
                    text = ""
                }
            }
        }
    }
}
