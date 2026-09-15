import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "FocusTheme.js" as Theme

// Full app window: sidebar nav + tasks or projects area.
Rectangle {
    id: root

    property var  service:      null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
    }
    property date selectedDate: new Date()
    signal closeRequested()

    implicitWidth:  720
    implicitHeight: 480
    color:          _theme.bgPanel
    radius:         Theme.radiusLg

    // ── Active view: 0=Tasks, 1=Projects ─────────────────────────────────
    property int _view: 0

    // Edit/delete modal state
    property var editTask:          null
    property var confirmDeleteTask: null

    property bool settingRollIncomplete: service ? service.rollIncomplete : false

    // ── Delete confirmation overlay ───────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: root.confirmDeleteTask !== null
        z: 20

        MouseArea { anchors.fill: parent; onClicked: root.confirmDeleteTask = null }

        Rectangle {
            anchors.centerIn: parent
            width: 300
            implicitHeight: delCol.implicitHeight + 32
            color: _theme.bgPanel
            radius: Theme.radiusMd
            border.color: _theme.border
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
                    color: _theme.textPrimary
                    Layout.fillWidth: true
                }
                Text {
                    text: root.confirmDeleteTask ? "\"" + root.confirmDeleteTask.title + "\"" : ""
                    font.pixelSize: Theme.fontMd
                    color: _theme.textSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: delCancelLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm; color: _theme.bgItem
                        Text { id: delCancelLbl; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontMd; color: _theme.textSecondary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmDeleteTask = null }
                    }
                    Rectangle {
                        implicitWidth: delConfirmLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm; color: _theme.danger
                        Text { id: delConfirmLbl; anchors.centerIn: parent; text: "Delete"; font.pixelSize: Theme.fontMd; color: "white"; font.weight: Font.Medium }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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

    // ── Edit task modal overlay ───────────────────────────────────────────
    Rectangle {
        id: editOverlay
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: root.editTask !== null
        z: 20

        MouseArea { anchors.fill: parent; onClicked: root.editTask = null }

        property var _editProjectId: null  // null = no project

        Rectangle {
            anchors.centerIn: parent
            width: 440
            implicitHeight: editCol.implicitHeight + 32
            color: _theme.bgPanel
            radius: Theme.radiusMd
            border.color: _theme.border
            border.width: 1
            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: editCol
                anchors { fill: parent; margins: 18 }
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Edit task"
                        font.pixelSize: Theme.fontLg; font.weight: Font.Medium
                        color: _theme.textPrimary; Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 6
                        color: closeEditArea.containsMouse ? _theme.bgHover : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: Theme.fontSm; color: _theme.textMuted }
                        MouseArea { id: closeEditArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editTask = null }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Title
                Text { text: "Title"; font.pixelSize: Theme.fontSm; color: _theme.textSecondary }
                TextField {
                    id: editTitleField
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontMd
                    color: _theme.textPrimary
                    placeholderTextColor: _theme.textMuted
                    leftPadding: 10; rightPadding: 10
                    background: Rectangle { color: _theme.bgItem; radius: Theme.radiusSm; border.color: editTitleField.activeFocus ? _theme.accent : "transparent"; border.width: 1 }
                }

                // Date + Est. mins
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Date"; font.pixelSize: Theme.fontSm; color: _theme.textSecondary }
                        FocusDatePicker {
                            id: editDateField
                            Layout.fillWidth: true
                            service: root.service
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 100
                        spacing: 4
                        Text { text: "Est. minutes"; font.pixelSize: Theme.fontSm; color: _theme.textSecondary }
                        TextField {
                            id: editMinsField
                            Layout.fillWidth: true
                            font.pixelSize: Theme.fontMd
                            color: _theme.textPrimary
                            placeholderText: "–"
                            placeholderTextColor: _theme.textMuted
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 0; top: 9999 }
                            leftPadding: 10; rightPadding: 10
                            background: Rectangle { color: _theme.bgItem; radius: Theme.radiusSm; border.color: editMinsField.activeFocus ? _theme.accent : "transparent"; border.width: 1 }
                        }
                    }
                }

                // Project selector
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text { text: "Projeto"; font.pixelSize: Theme.fontSm; color: _theme.textSecondary }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 5

                        // "Nenhum" pill
                        Rectangle {
                            property bool sel: editOverlay._editProjectId === null
                            implicitWidth: noneLabel.implicitWidth + 16
                            implicitHeight: 26
                            radius: Theme.radiusSm
                            color: sel ? _theme.bgHover : _theme.bgItem
                            border.color: sel ? _theme.accent : _theme.border
                            border.width: 1
                            Text {
                                id: noneLabel
                                anchors.centerIn: parent
                                text: "Nenhum"
                                font.pixelSize: Theme.fontSm
                                color: sel ? _theme.textPrimary : _theme.textSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: editOverlay._editProjectId = null
                            }
                        }

                        // One pill per project
                        Repeater {
                            model: service ? service.projects : []
                            delegate: Rectangle {
                                property bool sel: editOverlay._editProjectId === modelData.id
                                property string pColor: modelData.color || _theme.accent
                                implicitWidth: projPillLabel.implicitWidth + 24
                                implicitHeight: 26
                                radius: Theme.radiusSm
                                color: sel ? _theme.bgHover : _theme.bgItem
                                border.color: sel ? pColor : _theme.border
                                border.width: 1
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Rectangle {
                                        width: 7; height: 7; radius: 4
                                        color: pColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        id: projPillLabel
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSm
                                        color: sel ? _theme.textPrimary : _theme.textSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: editOverlay._editProjectId = modelData.id
                                }
                            }
                        }
                    }
                }

                // Notes / Description
                Text { text: "Description"; font.pixelSize: Theme.fontSm; color: _theme.textSecondary }
                ScrollView {
                    Layout.fillWidth: true
                    implicitHeight: 120
                    clip: true

                    TextArea {
                        id: editNotesField
                        width: parent.width
                        font.pixelSize: Theme.fontMd
                        color: _theme.textPrimary
                        placeholderText: "Add a description…"
                        placeholderTextColor: _theme.textMuted
                        wrapMode: TextEdit.Wrap
                        background: Rectangle { color: _theme.bgItem; radius: Theme.radiusSm }
                        leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: resetLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm; color: _theme.bgItem
                        Text { id: resetLbl; anchors.centerIn: parent; text: "Reset time"; font.pixelSize: Theme.fontMd; color: Qt.rgba(0.9, 0.4, 0.4, 1) }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.service && root.editTask) root.service.resetTaskTime(root.editTask.id)
                                root.editTask = null
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelEditLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm; color: _theme.bgItem
                        Text { id: cancelEditLbl; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontMd; color: _theme.textSecondary }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editTask = null }
                    }

                    Rectangle {
                        implicitWidth: saveLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm; color: _theme.accent
                        Text { id: saveLbl; anchors.centerIn: parent; text: "Save"; font.pixelSize: Theme.fontMd; color: "white"; font.weight: Font.Medium }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.service || !root.editTask) return
                                var mins = parseInt(editMinsField.text)
                                var dateVal = /\d{4}-\d{2}-\d{2}/.test(editDateField.value) ? editDateField.value : ""
                                var taskId = root.editTask.id
                                root.service.editTask(
                                    taskId,
                                    editTitleField.text.trim(),
                                    dateVal,
                                    isNaN(mins) ? -1 : mins,
                                    editNotesField.text
                                )
                                root.service.editTaskProject(taskId, editOverlay._editProjectId)
                                root.editTask = null
                            }
                        }
                    }
                }
            }

            // Populate fields when modal opens
            Component.onCompleted: { }
        }

        onVisibleChanged: {
            if (visible && root.editTask) {
                editTitleField.text = root.editTask.title || ""
                editDateField.value = root.editTask.scheduled_date || ""
                editMinsField.text  = root.editTask.estimated_mins ? String(root.editTask.estimated_mins) : ""
                editNotesField.text = root.editTask.notes || ""
                editOverlay._editProjectId = root.editTask.project_id || null
                editTitleField.forceActiveFocus()
            }
        }
    }

    // ── Settings modal ────────────────────────────────────────────────────
    Rectangle {
        id: settingsOverlay
        anchors.fill: parent
        anchors.margins: 1
        radius: Theme.radiusLg
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: false
        z: 10

        property string _savedTheme: "dark"
        property bool   _pendingRoll: false

        onVisibleChanged: {
            if (visible) {
                _savedTheme  = service ? service.currentTheme : "dark"
                _pendingRoll = root.settingRollIncomplete
            }
        }

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 480
            height: settingsCol.implicitHeight + 40
            color: _theme.bgPanel
            radius: Theme.radiusMd
            border.color: _theme.border
            border.width: 1

            ColumnLayout {
                id: settingsCol
                anchors { fill: parent; margins: 20 }
                spacing: 16

                // Title
                Text {
                    text: "Settings"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Medium
                    color: _theme.textPrimary
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Roll over incomplete tasks
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: "Roll over incomplete tasks"; font.pixelSize: Theme.fontMd; color: _theme.textPrimary }
                        Text {
                            text: "Unfinished tasks from past days are\nautomatically rescheduled to today."
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        width: 40; height: 22; radius: 11
                        color: settingsOverlay._pendingRoll ? _theme.accent : _theme.bgItem
                        border.color: settingsOverlay._pendingRoll ? _theme.accent : _theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: settingsOverlay._pendingRoll ? parent.width - width - 3 : 3
                            color: "white"
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsOverlay._pendingRoll = !settingsOverlay._pendingRoll
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Theme picker — 3-column grid with scroll
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text { text: "Theme"; font.pixelSize: Theme.fontMd; color: _theme.textPrimary }

                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(themeGrid.implicitHeight, 114)  // 3 rows × 34px + 2×6px gap
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Grid {
                            id: themeGrid
                            width: parent.width
                            columns: 3
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                model: {
                                    if (!service || !service.themes) return []
                                    return Object.keys(service.themes).map(function(k) {
                                        var t = service.themes[k]
                                        return { key: k, label: t.name || k, dot: t.accent || "#888" }
                                    })
                                }

                                delegate: Rectangle {
                                    property bool isActive: service && service.currentTheme === modelData.key
                                    width: (themeGrid.width - themeGrid.columnSpacing * 2) / 3
                                    height: 34
                                    radius: Theme.radiusSm
                                    color: isActive ? _theme.bgHover : _theme.bgItem
                                    border.color: isActive ? _theme.accent : _theme.border
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: modelData.dot
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: Theme.fontSm
                                            color: isActive ? _theme.textPrimary : _theme.textSecondary
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: Math.min(implicitWidth,
                                                   (themeGrid.width - themeGrid.columnSpacing * 2) / 3 - 30)
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (service) service.currentTheme = modelData.key }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Cancel + Save buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: cancelLbl.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm
                        color: cancelSettingsArea.containsMouse ? _theme.bgHover : _theme.bgItem
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { id: cancelLbl; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: Theme.fontMd; color: _theme.textSecondary }

                        MouseArea {
                            id: cancelSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (service) service.currentTheme = settingsOverlay._savedTheme
                                settingsOverlay.visible = false
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: saveLbl2.implicitWidth + 24; implicitHeight: 32
                        radius: Theme.radiusSm
                        color: saveSettingsArea.containsMouse ? _theme.accentDim : _theme.accent
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text { id: saveLbl2; anchors.centerIn: parent; text: "Save"; font.pixelSize: Theme.fontMd; color: "white"; font.weight: Font.Medium }

                        MouseArea {
                            id: saveSettingsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (service) {
                                    service.persistTheme(service.currentTheme)
                                    service.setRollIncomplete(settingsOverlay._pendingRoll)
                                }
                                root.settingRollIncomplete = settingsOverlay._pendingRoll
                                settingsOverlay.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Main layout: sidebar + content ────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ───────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 64
            Layout.fillHeight: true
            color: Qt.rgba(0, 0, 0, 0.25)
            radius: Theme.radiusLg

            ColumnLayout {
                anchors { fill: parent; topMargin: 14; bottomMargin: 14; leftMargin: 6; rightMargin: 6 }
                spacing: 2

                Repeater {
                    model: [
                        { label: "Tarefas",  idx: 0 },
                        { label: "Projetos", idx: 1 }
                    ]
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        radius: Theme.radiusSm
                        color: root._view === modelData.idx ? _theme.bgItem : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSm
                            color: root._view === modelData.idx
                                   ? _theme.textPrimary : _theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._view = modelData.idx
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Gear icon at bottom of sidebar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Theme.radiusSm
                    color: gearSidebarArea.containsMouse ? _theme.bgItem : "transparent"

                    Image {
                        anchors.centerIn: parent
                        source: Theme.iconsPath + "cog-6-tooth.svg"
                        width: 16; height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: gearSidebarArea.containsMouse ? 1.0 : 0.45
                    }

                    MouseArea {
                        id: gearSidebarArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsOverlay.visible = true
                    }
                }
            }
        }

        // ── Content area ──────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── Tasks view ────────────────────────────────────────────
            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: root._view === 0

                // Left panel: tabs + task list + add input
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // Tab bar / header row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        Layout.leftMargin: 16
                        Layout.rightMargin: 12
                        spacing: 6

                        // App title / date heading
                        Text {
                            text: {
                                var today = new Date()
                                if (Qt.formatDate(root.selectedDate, "yyyy-MM-dd")
                                        === Qt.formatDate(today, "yyyy-MM-dd"))
                                    return "Hoje"
                                return Qt.formatDate(root.selectedDate, "d MMM")
                            }
                            font.pixelSize: Theme.fontXl
                            font.weight: Font.SemiBold
                            color: _theme.textPrimary
                            Layout.fillWidth: true
                        }

                        // Completion count badge
                        Rectangle {
                            visible: service && tabRow.currentTab === 0
                            implicitWidth: doneCountText.implicitWidth + 14
                            implicitHeight: 20
                            radius: 10
                            color: _theme.bgItem

                            Text {
                                id: doneCountText
                                anchors.centerIn: parent
                                text: {
                                    if (!service) return ""
                                    var tasks = service.tasksForDate(root.selectedDate)
                                    var done = tasks.filter(function(t) { return t.completed }).length
                                    return done + " / " + tasks.length
                                }
                                font.pixelSize: Theme.fontSm
                                color: _theme.textSecondary
                            }
                        }

                        Row {
                            id: tabRow
                            spacing: 2
                            property int currentTab: 0

                            Repeater {
                                model: ["Hoje", "Não agendadas"]
                                delegate: Rectangle {
                                    implicitWidth:  tabLabel.implicitWidth + 16
                                    implicitHeight: 26
                                    radius: Theme.radiusSm
                                    color: tabRow.currentTab === index ? _theme.bgItem : "transparent"

                                    Text {
                                        id: tabLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSm
                                        color: tabRow.currentTab === index
                                               ? _theme.textPrimary : _theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: tabRow.currentTab = index
                                    }
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 12
                        Layout.topMargin: 6
                        height: 1; color: _theme.border
                        opacity: 0.6
                    }

                    // Task list
                    ListView {
                        id: taskList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.leftMargin: 8
                        Layout.rightMargin: 8
                        Layout.topMargin: 4
                        clip: true
                        spacing: 2

                        model: {
                            if (!service) return []
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
                        Layout.leftMargin: 16; Layout.rightMargin: 12
                        height: 1; color: _theme.border
                        opacity: 0.6
                    }

                    // Add task input row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 12
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
                            color: _theme.textPrimary
                            implicitWidth: 48
                            horizontalAlignment: Text.AlignHCenter
                            background: Rectangle {
                                color: _theme.bgItem
                                radius: Theme.radiusSm
                            }
                            Keys.onReturnPressed: addTaskField._submit()
                            Keys.onEscapePressed: { addTaskField.text = ""; addTaskField.focus = false }
                        }

                        Text {
                            text: "min"
                            visible: addTaskField.activeFocus || estMinsField.activeFocus
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }

                        TextField {
                            id: addTaskField
                            Layout.fillWidth: true
                            placeholderText: "Nova tarefa..."
                            color: _theme.textPrimary
                            placeholderTextColor: _theme.textMuted
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

                // Right panel: mini calendar
                Rectangle {
                    Layout.preferredWidth: 210
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: Theme.radiusLg

                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        // App title
                        Text {
                            text: "FocusTrack"
                            font.pixelSize: Theme.fontLg
                            font.weight: Font.Bold
                            color: _theme.textPrimary
                            font.letterSpacing: -0.3
                        }

                        // Calendar
                        FocusMonthCalendar {
                            id: cal
                            service: root.service
                            selectedDate: root.selectedDate
                            Layout.fillWidth: true
                            onDateSelected: function(d) { root.selectedDate = d }
                        }

                        Item { Layout.fillHeight: true }

                        // Today button
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            color: todayBtnArea.containsMouse ? _theme.bgHover : _theme.bgItem
                            radius: Theme.radiusSm
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "Ir para hoje"
                                font.pixelSize: Theme.fontSm
                                color: _theme.textPrimary
                            }

                            MouseArea {
                                id: todayBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
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
            }

            // ── Projects view ─────────────────────────────────────────
            FocusProjectsView {
                anchors { fill: parent; margins: 14 }
                visible: root._view === 1
                service: root.service
            }
        }
    }
}
