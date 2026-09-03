import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "FocusTheme.js" as Theme

// Full app window: calendar on left, day/unscheduled tasks on right.
Rectangle {
    id: root

    property var  service:      null
    property date selectedDate: new Date()
    signal closeRequested()

    // Edit modal state
    property var  editTask:        null   // task being edited, null = modal closed
    property var  confirmDeleteTask: null // task pending delete confirmation

    implicitWidth:  640
    implicitHeight: 420
    color:          Theme.bgPanel
    radius:         Theme.radiusLg

    // ── Delete confirmation overlay ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: root.confirmDeleteTask !== null
        z: 10

        MouseArea { anchors.fill: parent; onClicked: root.confirmDeleteTask = null }

        Rectangle {
            anchors.centerIn: parent
            width: 300
            implicitHeight: delCol.implicitHeight + 32
            color: Theme.bgPanel
            radius: Theme.radiusMd
            border.color: Theme.border
            border.width: 1

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: delCol
                anchors { fill: parent; margins: 20 }
                spacing: 14

                Text {
                    text: "Delete task?"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                Text {
                    text: root.confirmDeleteTask ? "\"" + root.confirmDeleteTask.title + "\"" : ""
                    font.pixelSize: Theme.fontMd
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: delCancelLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.bgItem
                        Text {
                            id: delCancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontMd
                            color: Theme.textSecondary
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmDeleteTask = null }
                    }

                    Rectangle {
                        implicitWidth: delConfirmLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.accent
                        Text {
                            id: delConfirmLabel
                            anchors.centerIn: parent
                            text: "Delete"
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service && root.confirmDeleteTask)
                                    root.service.deleteTask(root.confirmDeleteTask.id)
                                root.confirmDeleteTask = null
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Edit modal overlay ────────────────────────────────────────────────
    Rectangle {
        id: editOverlay
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: root.editTask !== null
        z: 10

        // dismiss on backdrop click
        MouseArea {
            anchors.fill: parent
            onClicked: root.editTask = null
        }

        Rectangle {
            id: editCard
            anchors.centerIn: parent
            width: 380
            implicitHeight: editCol.implicitHeight + 32
            color: Theme.bgPanel
            radius: Theme.radiusMd
            border.color: Theme.border
            border.width: 1

            // stop clicks propagating to backdrop
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: editCol
                anchors { fill: parent; margins: 16 }
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Edit task"
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                    Image {
                        source: Theme.iconsPath + "pencil-square.svg"
                        width: 15; height: 15
                        fillMode: Image.PreserveAspectFit
                    }
                }

                // Title
                Text { text: "Title"; font.pixelSize: Theme.fontSm; color: Theme.textSecondary }
                TextField {
                    id: editTitleField
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontMd
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textMuted
                    background: Rectangle {
                        color: Theme.bgItem
                        radius: Theme.radiusSm
                    }
                    leftPadding: 10; rightPadding: 10
                    text: root.editTask ? root.editTask.title : ""
                }

                // Date + Estimated mins (side by side)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Date (YYYY-MM-DD)"; font.pixelSize: Theme.fontSm; color: Theme.textSecondary }
                        TextField {
                            id: editDateField
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                            placeholderText: "none"
                            placeholderTextColor: Theme.textMuted
                            background: Rectangle { color: Theme.bgItem; radius: Theme.radiusSm }
                            leftPadding: 10; rightPadding: 10
                            text: root.editTask && root.editTask.scheduled_date
                                  ? root.editTask.scheduled_date : ""
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 110
                        spacing: 4
                        Text { text: "Est. minutes"; font.pixelSize: Theme.fontSm; color: Theme.textSecondary }
                        TextField {
                            id: editMinsField
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                            placeholderText: "–"
                            placeholderTextColor: Theme.textMuted
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: Theme.bgItem; radius: Theme.radiusSm }
                            leftPadding: 10; rightPadding: 10
                            text: root.editTask && root.editTask.estimated_mins
                                  ? String(root.editTask.estimated_mins) : ""
                        }
                    }
                }

                // Notes
                Text { text: "Notes"; font.pixelSize: Theme.fontSm; color: Theme.textSecondary }
                TextArea {
                    id: editNotesField
                    Layout.fillWidth: true
                    implicitHeight: 72
                    font.pixelSize: Theme.fontMd
                    color: Theme.textPrimary
                    placeholderText: "Add notes…"
                    placeholderTextColor: Theme.textMuted
                    wrapMode: TextEdit.Wrap
                    background: Rectangle { color: Theme.bgItem; radius: Theme.radiusSm }
                    leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
                    text: root.editTask && root.editTask.notes ? root.editTask.notes : ""
                }

                // Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Reset time
                    Rectangle {
                        implicitWidth: resetLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.bgItem

                        Text {
                            id: resetLabel
                            anchors.centerIn: parent
                            text: "Reset time"
                            font.pixelSize: Theme.fontMd
                            color: Qt.rgba(0.9, 0.4, 0.4, 1)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service && root.editTask)
                                    root.service.resetTaskTime(root.editTask.id)
                                root.editTask = null
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Cancel
                    Rectangle {
                        implicitWidth: cancelLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.bgItem

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontMd
                            color: Theme.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editTask = null
                        }
                    }

                    // Save
                    Rectangle {
                        implicitWidth: saveLabel.implicitWidth + 24
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: Theme.accent

                        Text {
                            id: saveLabel
                            anchors.centerIn: parent
                            text: "Save"
                            font.pixelSize: Theme.fontMd
                            color: Theme.textPrimary
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.service || !root.editTask) return
                                var mins = parseInt(editMinsField.text)
                                root.service.editTask(
                                    root.editTask.id,
                                    editTitleField.text.trim(),
                                    editDateField.text.trim(),
                                    isNaN(mins) ? -1 : mins,
                                    editNotesField.text
                                )
                                root.editTask = null
                            }
                        }
                    }
                }
            }
        }

        // Populate fields when modal opens
        onVisibleChanged: {
            if (visible && root.editTask) {
                editTitleField.text = root.editTask.title || ""
                editDateField.text  = root.editTask.scheduled_date || ""
                editMinsField.text  = root.editTask.estimated_mins
                                      ? String(root.editTask.estimated_mins) : ""
                editNotesField.text = root.editTask.notes || ""
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
                    }
                }

                // Calendar
                FocusMonthCalendar {
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
                        cursorShape: Qt.PointingHandCursor
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
                                cursorShape: Qt.PointingHandCursor
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
                    void service.tasks  // explicit dependency so model reacts to task changes
                    if (tabRow.currentTab === 0) {
                        return service.tasksForDate(root.selectedDate)
                    } else {
                        return service.unscheduledTasks()
                    }
                }

                delegate: FocusFullTaskItem {
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

                    onDoneClicked: {
                        if (!service) return
                        if (task.completed) service.undoneTask(task.id)
                        else                service.doneTask(task.id)
                    }
                    onDeleteClicked: { root.confirmDeleteTask = task }
                    onEditClicked:   { root.editTask = task }
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
