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
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
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

    // Kanban column classification
    function columnForStatus(status) {
        if (!status) return 0
        var s = status.toLowerCase()
        if (s === "done" || s === "completed" || s === "finished") return 2
        if (s === "active" || s === "inprogress" || s === "in_progress") return 1
        return 0  // backlog / planning / created / anything else
    }

    function projectsForColumn(col) {
        if (!service || !service.projects) return []
        return service.projects.filter(function(p) {
            return root.columnForStatus(p.status) === col
        })
    }

    // ── New-project modal state ───────────────────────────────────────────────

    property bool _showModal:    false
    property bool _editMode:     false
    property var  _editTarget:   null

    property string _fieldName:        ""
    property string _fieldColor:       "#e53935"
    property string _fieldStatus:      "Created"
    property string _fieldStartDate:   ""
    property string _fieldEndDate:     ""
    property string _fieldEstMins:     ""
    property string _fieldDescription: ""

    function _openNew() {
        _editMode        = false
        _editTarget      = null
        _fieldName        = ""
        _fieldColor       = "#e53935"
        _fieldStatus      = "Created"
        _fieldStartDate   = ""
        _fieldEndDate     = ""
        _fieldEstMins     = ""
        _fieldDescription = ""
        _showModal = true
    }

    function _openEdit(project) {
        _editMode        = true
        _editTarget      = project
        _fieldName        = project.name        || ""
        _fieldColor       = project.color       || "#e53935"
        _fieldStatus      = project.status      || "Created"
        _fieldStartDate   = project.start_date  || ""
        _fieldEndDate     = project.end_date    || ""
        _fieldEstMins     = project.estimated_mins ? String(project.estimated_mins) : ""
        _fieldDescription = project.description || ""
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

    // ── Kanban column component ───────────────────────────────────────────────

    component KanbanColumn: Rectangle {
        id: colRoot
        property string columnTitle: ""
        property var    projects:    []
        property color  accentCol:   _theme.accent

        color: Qt.rgba(0, 0, 0, 0.12)
        radius: Theme.radiusMd

        ColumnLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 8

            // Column header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: colRoot.accentCol
                }

                Text {
                    text: colRoot.columnTitle
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.SemiBold
                    color: _theme.textPrimary
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth:  colCountLbl.implicitWidth + 8
                    implicitHeight: 18
                    radius: 9
                    color: _theme.bgItem

                    Text {
                        id: colCountLbl
                        anchors.centerIn: parent
                        text: String(colRoot.projects.length)
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: _theme.border
                opacity: 0.5
            }

            // Project cards
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: colRoot.projects

                delegate: Rectangle {
                    id: projCard
                    property var project: modelData
                    property bool hovered: false

                    width:  parent ? parent.width : 0
                    height: projCardCol.implicitHeight + 16
                    radius: Theme.radiusSm
                    color:  projCard.hovered ? _theme.bgHover : _theme.bgItem

                    Behavior on color { ColorAnimation { duration: 100 } }

                    // Left accent bar
                    Rectangle {
                        id: cardAccentBar
                        width: 3
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 4; bottomMargin: 4 }
                        radius: 2
                        color: projCard.project.color || _theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onContainsMouseChanged: projCard.hovered = containsMouse
                    }

                    // Hover action icons
                    RowLayout {
                        anchors { top: parent.top; right: parent.right; topMargin: 5; rightMargin: 6 }
                        spacing: 4
                        opacity: projCard.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        // Edit button
                        Rectangle {
                            width: 26; height: 26; radius: Theme.radiusSm
                            color: cardEditArea.containsMouse ? _theme.bgHover : Qt.rgba(1,1,1,0.06)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Image {
                                anchors.centerIn: parent
                                source: Theme.iconsPath + "pencil-square.svg"
                                width: 14; height: 14
                                fillMode: Image.PreserveAspectFit
                                opacity: cardEditArea.containsMouse ? 1.0 : 0.75
                            }

                            MouseArea {
                                id: cardEditArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._openEdit(projCard.project)
                            }
                        }

                        // Delete button — danger-tinted always
                        Rectangle {
                            width: 26; height: 26; radius: Theme.radiusSm
                            property real dr: parseInt(_theme.danger.slice(1,3), 16) / 255
                            property real dg: parseInt(_theme.danger.slice(3,5), 16) / 255
                            property real db: parseInt(_theme.danger.slice(5,7), 16) / 255
                            color: cardDeleteArea.containsMouse
                                ? Qt.rgba(dr, dg, db, 0.30)
                                : Qt.rgba(dr, dg, db, 0.14)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Image {
                                anchors.centerIn: parent
                                source: Theme.iconsPath + "trash.svg"
                                width: 14; height: 14
                                fillMode: Image.PreserveAspectFit
                                opacity: cardDeleteArea.containsMouse ? 1.0 : 0.85
                            }

                            MouseArea {
                                id: cardDeleteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (service) service.deleteProject(projCard.project.id)
                                }
                            }
                        }
                    }

                    // Card content
                    ColumnLayout {
                        id: projCardCol
                        anchors {
                            left:   cardAccentBar.right
                            right:  parent.right
                            top:    parent.top
                            leftMargin: 8; rightMargin: 8; topMargin: 8
                        }
                        spacing: 4

                        // Project name
                        Text {
                            text: projCard.project.name || ""
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.DemiBold
                            color: _theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.rightMargin: projCard.hovered ? 50 : 0
                        }

                        // Task count + estimated mins row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: root.taskCountForProject(projCard.project.id) + " tarefa" +
                                      (root.taskCountForProject(projCard.project.id) === 1 ? "" : "s")
                                font.pixelSize: Theme.fontSm
                                color: _theme.textMuted
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                visible: projCard.project.estimated_mins > 0
                                text: projCard.project.estimated_mins + "min"
                                font.pixelSize: Theme.fontSm
                                color: _theme.textMuted
                            }
                        }

                        // Dates
                        Text {
                            visible: (projCard.project.start_date || "") !== ""
                                  || (projCard.project.end_date   || "") !== ""
                            text: {
                                var s = projCard.project.start_date || ""
                                var e = projCard.project.end_date   || ""
                                if (s && e) return s + " → " + e
                                if (s)      return "De " + s
                                if (e)      return "Até " + e
                                return ""
                            }
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                            Layout.fillWidth: true
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
        }
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
                text: "Projetos"
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
                    text: "+ Novo projeto"
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

        // Kanban columns
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            KanbanColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columnTitle: "Backlog"
                projects: root.projectsForColumn(0)
                accentCol: _theme.textMuted
            }

            KanbanColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columnTitle: "Em progresso"
                projects: root.projectsForColumn(1)
                accentCol: _theme.accent
            }

            KanbanColumn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columnTitle: "Concluído"
                projects: root.projectsForColumn(2)
                accentCol: _theme.accentAlt
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
            width:  480
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
                        text: root._editMode ? "Editar projeto" : "Novo projeto"
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
                            text: "✕"
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
                        text: "Nome"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        text: root._fieldName
                        placeholderText: "Nome do projeto"
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

                // Description
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Descrição"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 90
                        clip: true

                        TextArea {
                            id: descField
                            width: parent.width
                            font.pixelSize: Theme.fontMd
                            color: _theme.textPrimary
                            placeholderText: "Descreva o projeto…"
                            placeholderTextColor: _theme.textMuted
                            wrapMode: TextEdit.Wrap
                            text: root._fieldDescription
                            onTextChanged: root._fieldDescription = text
                            background: Rectangle {
                                color: _theme.bgItem
                                radius: Theme.radiusSm
                                border.color: descField.activeFocus ? _theme.accent : _theme.border
                                border.width: 1
                            }
                            leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
                            Keys.onEscapePressed: root._showModal = false
                        }
                    }
                }

                // Color picker
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Cor"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    Grid {
                        columns: 10
                        spacing: 6
                        Layout.fillWidth: true

                        Repeater {
                            model: [
                                "#EF4444", "#F97316", "#EAB308", "#22C55E", "#10B981",
                                "#06B6D4", "#3B82F6", "#6366F1", "#8B5CF6", "#EC4899",
                                "#F43F5E", "#FB923C", "#84CC16", "#14B8A6", "#0EA5E9",
                                "#6D28D9", "#BE185D", "#78716C", "#94A3B8", "#FFFFFF"
                            ]

                            delegate: Rectangle {
                                width: 24; height: 24; radius: 12
                                color: modelData
                                border.color: root._fieldColor === modelData
                                    ? "white" : Qt.rgba(1,1,1,0.15)
                                border.width: root._fieldColor === modelData ? 2 : 1

                                Rectangle {
                                    visible: root._fieldColor === modelData
                                    anchors.centerIn: parent
                                    width: 8; height: 8; radius: 4
                                    color: "white"
                                    opacity: 0.9
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
                                { key: "Created",    label: "Backlog"      },
                                { key: "InProgress", label: "Em progresso" },
                                { key: "Completed",  label: "Concluído"    }
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
                                    color: active ? _theme.accent : _theme.textMuted
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
                        text: "Data de início (opcional)"
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
                        text: "Data de término (opcional)"
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
                        text: "Minutos estimados (opcional)"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                    }

                    TextField {
                        id: estMinsField
                        Layout.fillWidth: true
                        text: root._fieldEstMins
                        placeholderText: "ex: 120"
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

                    Rectangle {
                        implicitWidth:  cancelLabel.implicitWidth + 20
                        implicitHeight: 30
                        radius: Theme.radiusSm
                        color: cancelArea.containsMouse ? _theme.bgHover : _theme.bgItem
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: cancelLabel
                            anchors.centerIn: parent
                            text: "Cancelar"
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
                            text: root._editMode ? "Salvar" : "Criar"
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
