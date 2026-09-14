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

    property bool settingRollIncomplete: service ? service.rollIncomplete : false

    // ── Settings modal ────────────────────────────────────────────────────
    Rectangle {
        id: settingsOverlay
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: false
        z: 10

        MouseArea { anchors.fill: parent } // block clicks through

        Rectangle {
            anchors.centerIn: parent
            width: 340
            height: settingsCol.implicitHeight + 40
            color: Theme.bgPanel
            radius: Theme.radiusMd
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
                id: settingsCol
                anchors { fill: parent; margins: 20 }
                spacing: 16

                // Title row
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Settings"
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 24; height: 24
                        radius: 6
                        color: closeSettingsArea.containsMouse ? Theme.bgHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: Theme.fontSm
                            color: Theme.textMuted
                        }
                        MouseArea {
                            id: closeSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsOverlay.visible = false
                        }
                    }
                }

                // Divider
                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                // Setting: Roll incomplete tasks
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "Roll over incomplete tasks"
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                        }
                        Text {
                            text: "Unfinished tasks from past days are\nautomatically rescheduled to today."
                            font.pixelSize: Theme.fontSm
                            color: Theme.textMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    // Toggle switch
                    Rectangle {
                        width: 40; height: 22
                        radius: 11
                        color: root.settingRollIncomplete ? Theme.accent : Theme.bgItem
                        border.color: root.settingRollIncomplete ? Theme.accent : Theme.border
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 16; height: 16
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.settingRollIncomplete ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.settingRollIncomplete = !root.settingRollIncomplete
                                if (service) service.setRollIncomplete(root.settingRollIncomplete)
                            }
                        }
                    }
                }
            }
        }
    }

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
                    Image {
                        source: Theme.iconsPath + "cog-6-tooth.svg"
                        width: 16; height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: gearArea.containsMouse ? 1.0 : 0.5
                        MouseArea {
                            id: gearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsOverlay.visible = true
                        }
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

            // Add task input row
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6
                Layout.bottomMargin: 12
                spacing: 8

                // Estimated mins — visible when either field is focused
                TextField {
                    id: estMinsField
                    text: "30"
                    visible: addTaskField.activeFocus || estMinsField.activeFocus
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 999 }
                    font.pixelSize: Theme.fontSm
                    color: Theme.textPrimary
                    implicitWidth: 48
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        color: Theme.bgItem
                        radius: Theme.radiusSm
                    }
                    Keys.onReturnPressed: addTaskField._submit()
                    Keys.onEscapePressed: { addTaskField.text = ""; addTaskField.focus = false }
                }

                Text {
                    text: "min"
                    visible: addTaskField.activeFocus || estMinsField.activeFocus
                    font.pixelSize: Theme.fontSm
                    color: Theme.textMuted
                }

                TextField {
                    id: addTaskField
                    Layout.fillWidth: true
                    placeholderText: "Add a task"
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textMuted
                    font.pixelSize: Theme.fontMd
                    background: Rectangle { color: "transparent" }

                    function _submit() {
                        var title = text.trim()
                        if (title === "" || !service) return
                        var mins = parseInt(estMinsField.text) || 0
                        if (tabRow.currentTab === 0) {
                            var iso = Qt.formatDate(root.selectedDate, "yyyy-MM-dd")
                            service.addTask(title, iso, mins)
                        } else {
                            service.addTask(title, null, mins)
                        }
                        text = ""
                        estMinsField.text = "30"
                        addTaskField.focus = false
                    }

                    Keys.onReturnPressed: _submit()
                    Keys.onTabPressed:    { estMinsField.forceActiveFocus(); event.accepted = true }
                    Keys.onEscapePressed: { text = ""; focus = false }
                }
            }
        }
    }
}
