import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "FocusTheme.js" as Theme

Rectangle {
    id: root

    property var service: null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border
    }

    color: "transparent"

    // ── Helpers ───────────────────────────────────────────────────────────────

    function taskCountForProject(projectId) {
        if (!service || !service.tasks) return 0
        var count = 0
        for (var i = 0; i < service.tasks.length; i++) {
            if (service.tasks[i].project_id === projectId) count++
        }
        return count
    }

    function statusColor(status) {
        if (status === "InProgress")  return _theme.accent
        if (status === "Completed")   return "#4caf50"
        return _theme.textMuted
    }

    function statusLabel(status) {
        if (status === "InProgress")  return "In Progress"
        if (status === "Completed")   return "Completed"
        return "Created"
    }

    // ── New-project modal state ───────────────────────────────────────────────

    property bool _showModal:    false
    property bool _editMode:     false
    property var  _editTarget:   null

    property string _fieldName:      ""
    property string _fieldColor:     "#e53935"
    property string _fieldStatus:    "Created"
    property string _fieldStartDate: ""
    property string _fieldEndDate:   ""
    property string _fieldEstMins:   ""

    function _openNew() {
        _editMode     = false
        _editTarget   = null
        _fieldName      = ""
        _fieldColor     = "#e53935"
        _fieldStatus    = "Created"
        _fieldStartDate = ""
        _fieldEndDate   = ""
        _fieldEstMins   = ""
        _showModal = true
    }

    function _openEdit(project) {
        _editMode     = true
        _editTarget   = project
        _fieldName      = project.name      || ""
        _fieldColor     = project.color     || "#e53935"
        _fieldStatus    = project.status    || "Created"
        _fieldStartDate = project.start_date || ""
        _fieldEndDate   = project.end_date   || ""
        _fieldEstMins   = project.estimated_mins ? String(project.estimated_mins) : ""
        _showModal = true
    }

    function _submit() {
        if (!service || _fieldName.trim() === "") return
        var mins = parseInt(_fieldEstMins) || 0
        if (_editMode && _editTarget) {
            service.editProject(
                _editTarget.id,
                _fieldName.trim(),
                _fieldColor,
                _fieldStatus,
                _fieldStartDate || null,
                _fieldEndDate   || null,
                mins
            )
        } else {
            service.addProject(
                _fieldName.trim(),
                _fieldColor,
                _fieldStatus,
                _fieldStartDate || null,
                _fieldEndDate   || null,
                mins
            )
        }
        _showModal = false
    }

    // ── Main layout ───────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 14

        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Projects"
                font.pixelSize: Theme.fontXl
                font.weight: Font.Medium
                color: _theme.textPrimary
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth:  newBtnLabel.implicitWidth + 18
                implicitHeight: 28
                radius: Theme.radiusSm
                color: newBtnArea.containsMouse ? _theme.accentDim : _theme.accent

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    id: newBtnLabel
                    anchors.centerIn: parent
                    text: "+ New project"
                    font.pixelSize: Theme.fontSm
                    color: "white"
                }

                MouseArea {
                    id: newBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._openNew()
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !service || !service.projects || service.projects.length === 0

            Text {
                anchors.centerIn: parent
                text: "No projects yet"
                font.pixelSize: Theme.fontMd
                color: _theme.textMuted
            }
        }

        // Project grid (Flow layout)
        Flow {
            id: projectsGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            visible: service && service.projects && service.projects.length > 0

            Repeater {
                model: service ? service.projects : []

                delegate: Rectangle {
                    id: card

                    property var project: modelData
                    property bool hovered: false

                    width:  208
                    height: cardCol.implicitHeight + 20
                    radius: Theme.radiusMd
                    color:  _theme.bgItem

                    // Left colored border accent
                    Rectangle {
                        id: leftAccent
                        width:   4
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        radius:  Theme.radiusSm
                        color:   card.project.color || _theme.accent
                    }

                    MouseArea {
                        id: cardHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onContainsMouseChanged: card.hovered = containsMouse
                    }

                    // Hover action icons (top-right)
                    RowLayout {
                        anchors { top: parent.top; right: parent.right; topMargin: 6; rightMargin: 6 }
                        spacing: 4
                        opacity: card.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        // Edit
                        Rectangle {
                            width: 24; height: 24
                            radius: Theme.radiusSm
                            color: editIconArea.containsMouse ? _theme.bgHover : "transparent"

                            Image {
                                anchors.centerIn: parent
                                source: Theme.iconsPath + "pencil-square.svg"
                                width: 14; height: 14
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: editIconArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._openEdit(card.project)
                            }
                        }

                        // Delete
                        Rectangle {
                            width: 24; height: 24
                            radius: Theme.radiusSm
                            color: deleteIconArea.containsMouse ? _theme.bgHover : "transparent"

                            Image {
                                anchors.centerIn: parent
                                source: Theme.iconsPath + "trash.svg"
                                width: 14; height: 14
                                fillMode: Image.PreserveAspectFit
                            }

                            MouseArea {
                                id: deleteIconArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (service) service.deleteProject(card.project.id)
                                }
                            }
                        }
                    }

                    // Card content
                    ColumnLayout {
                        id: cardCol
                        anchors { left: leftAccent.right; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 6

                        // Top row: dot + name
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: card.project.color || _theme.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: card.project.name || ""
                                font.pixelSize: Theme.fontMd
                                font.weight: Font.DemiBold
                                color: _theme.textPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Status badge
                        Rectangle {
                            implicitWidth:  statusText.implicitWidth + 12
                            implicitHeight: 18
                            radius: Theme.radiusSm
                            color: _theme.bgHover

                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: root.statusLabel(card.project.status)
                                font.pixelSize: Theme.fontSm
                                color: root.statusColor(card.project.status)
                            }
                        }

                        // Task count
                        Text {
                            text: root.taskCountForProject(card.project.id) + " tasks"
                            font.pixelSize: Theme.fontSm
                            color: _theme.textSecondary
                        }

                        // Estimated mins
                        Text {
                            visible: card.project.estimated_mins > 0
                            text:    (card.project.estimated_mins || 0) + "min est."
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }

                        // Dates
                        Text {
                            visible: (card.project.start_date || "") !== ""
                                  || (card.project.end_date   || "") !== ""
                            text: {
                                var s = card.project.start_date || ""
                                var e = card.project.end_date   || ""
                                if (s && e) return s + " - " + e
                                if (s)      return "From " + s
                                if (e)      return "Until " + e
                                return ""
                            }
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }
                    }
                }
            }
        }
    }

    // ── Modal overlay ─────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: root._showModal
        z: 10

        MouseArea { anchors.fill: parent } // block clicks through

        Rectangle {
            anchors.centerIn: parent
            width:  340
            height: modalCol.implicitHeight + 40
            color:  _theme.bgPanel
            radius: Theme.radiusMd
            border.color: _theme.border
            border.width: 1

            ColumnLayout {
                id: modalCol
                anchors { fill: parent; margins: 20 }
                spacing: 14

                // Title row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root._editMode ? "Edit project" : "New project"
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.Medium
                        color: _theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 24; height: 24
                        radius: 6
                        color: closeBtnArea.containsMouse ? _theme.bgHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "x"
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }

                        MouseArea {
                            id: closeBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._showModal = false
                        }
                    }
                }

                // Divider
                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Name field
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Name"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        text: root._fieldName
                        placeholderText: "Project name"
                        placeholderTextColor: _theme.textMuted
                        color: _theme.textPrimary
                        font.pixelSize: Theme.fontMd
                        onTextChanged: root._fieldName = text
                        background: Rectangle {
                            color: _theme.bgItem
                            radius: Theme.radiusSm
                            border.color: nameField.activeFocus ? _theme.accent : _theme.border
                            border.width: 1
                        }
                        Keys.onReturnPressed: root._submit()
                        Keys.onEscapePressed: root._showModal = false
                    }
                }

                // Color picker
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Color"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Repeater {
                            model: ["#e53935", "#4caf50", "#2196f3", "#ff9800", "#9c27b0", "#00bcd4"]

                            delegate: Rectangle {
                                width: 26; height: 26; radius: 13
                                color: modelData
                                border.color: root._fieldColor === modelData ? "white" : "transparent"
                                border.width: 2

                                // Inner ring when selected
                                Rectangle {
                                    visible: root._fieldColor === modelData
                                    anchors.centerIn: parent
                                    width: 10; height: 10; radius: 5
                                    color: "white"
                                    opacity: 0.8
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._fieldColor = modelData
                                }
                            }
                        }
                    }
                }

                // Status toggle
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Status"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Repeater {
                            model: [
                                { key: "Created",    label: "Created"     },
                                { key: "InProgress", label: "In Progress" },
                                { key: "Completed",  label: "Completed"   }
                            ]

                            delegate: Rectangle {
                                property bool active: root._fieldStatus === modelData.key
                                implicitWidth:  statusToggleLabel.implicitWidth + 14
                                implicitHeight: 26
                                radius: Theme.radiusSm
                                color: active ? _theme.bgHover : "transparent"
                                border.color: active ? _theme.accent : _theme.border
                                border.width: 1

                                Text {
                                    id: statusToggleLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSm
                                    color: active ? root.statusColor(modelData.key) : _theme.textMuted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._fieldStatus = modelData.key
                                }
                            }
                        }
                    }
                }

                // Start date
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Start date (optional)"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: startDateField
                        Layout.fillWidth: true
                        text: root._fieldStartDate
                        placeholderText: "YYYY-MM-DD"
                        placeholderTextColor: _theme.textMuted
                        color: _theme.textPrimary
                        font.pixelSize: Theme.fontMd
                        onTextChanged: root._fieldStartDate = text
                        background: Rectangle {
                            color: _theme.bgItem
                            radius: Theme.radiusSm
                            border.color: startDateField.activeFocus ? _theme.accent : _theme.border
                            border.width: 1
                        }
                        Keys.onReturnPressed: root._submit()
                        Keys.onEscapePressed: root._showModal = false
                    }
                }

                // End date
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "End date (optional)"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: endDateField
                        Layout.fillWidth: true
                        text: root._fieldEndDate
                        placeholderText: "YYYY-MM-DD"
                        placeholderTextColor: _theme.textMuted
                        color: _theme.textPrimary
                        font.pixelSize: Theme.fontMd
                        onTextChanged: root._fieldEndDate = text
                        background: Rectangle {
                            color: _theme.bgItem
                            radius: Theme.radiusSm
                            border.color: endDateField.activeFocus ? _theme.accent : _theme.border
                            border.width: 1
                        }
                        Keys.onReturnPressed: root._submit()
                        Keys.onEscapePressed: root._showModal = false
                    }
                }

                // Estimated mins
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Estimated minutes (optional)"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: estMinsField
                        Layout.fillWidth: true
                        text: root._fieldEstMins
                        placeholderText: "e.g. 120"
                        placeholderTextColor: _theme.textMuted
                        color: _theme.textPrimary
                        font.pixelSize: Theme.fontMd
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: IntValidator { bottom: 1; top: 99999 }
                        onTextChanged: root._fieldEstMins = text
                        background: Rectangle {
                            color: _theme.bgItem
                            radius: Theme.radiusSm
                            border.color: estMinsField.activeFocus ? _theme.accent : _theme.border
                            border.width: 1
                        }
                        Keys.onReturnPressed: root._submit()
                        Keys.onEscapePressed: root._showModal = false
                    }
                }

                // Divider
                Rectangle { Layout.fillWidth: true; height: 1; color: _theme.border }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    // Cancel
                    Rectangle {
                        implicitWidth:  cancelLabel.implicitWidth + 20
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: cancelArea.containsMouse ? _theme.bgHover : _theme.bgItem
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.pixelSize: Theme.fontMd
                            color: _theme.textSecondary
                        }

                        MouseArea {
                            id: cancelArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._showModal = false
                        }
                    }

                    // Create / Save
                    Rectangle {
                        implicitWidth:  submitLabel.implicitWidth + 20
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: submitArea.containsMouse ? _theme.accentDim : _theme.accent
                        Behavior on color { ColorAnimation { duration: 100 } }
                        opacity: root._fieldName.trim() !== "" ? 1.0 : 0.5

                        Text {
                            id: submitLabel
                            anchors.centerIn: parent
                            text: root._editMode ? "Save" : "Create"
                            font.pixelSize: Theme.fontMd
                            color: "white"
                        }

                        MouseArea {
                            id: submitArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._submit()
                        }
                    }
                }
            }
        }
    }
}
