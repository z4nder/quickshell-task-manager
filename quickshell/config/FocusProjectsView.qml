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
        var n = 0
        for (var i = 0; i < service.tasks.length; i++)
            if (service.tasks[i].project_id === projectId) n++
        return n
    }

    function doneCountForProject(projectId) {
        if (!service || !service.tasks) return 0
        var n = 0
        for (var i = 0; i < service.tasks.length; i++)
            if (service.tasks[i].project_id === projectId && service.tasks[i].completed) n++
        return n
    }

    function formatMins(mins) {
        if (!mins || mins <= 0) return "-"
        var h = Math.floor(mins / 60)
        var m = mins % 60
        if (h > 0 && m > 0) return h + "h " + m + "m"
        if (h > 0) return h + "h"
        return m + "m"
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
        _fieldStartDate   = Qt.formatDate(new Date(), "yyyy-MM-dd")
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

    // ── Main layout ───────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Header row
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Projetos"
                font.pixelSize: Theme.fontXl
                font.weight: Font.SemiBold
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

        // Project card grid — 3 per row
        GridView {
            id: projectGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: service ? service.projects : []
            cellWidth:  200
            cellHeight: 172
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Item {
                width:  projectGrid.cellWidth
                height: projectGrid.cellHeight

            Rectangle {
                id: projCard
                property var  project: modelData
                property bool hovered: false
                property int  total:   root.taskCountForProject(project.id)
                property int  done:    root.doneCountForProject(project.id)
                property string pColor: project.color || _theme.accent

                anchors { fill: parent; margins: 4 }
                radius: Theme.radiusMd
                color:  _theme.bgItem
                border.color: pColor
                border.width: 1.5

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: projCard.hovered = containsMouse
                }

                ColumnLayout {
                    id: cardBody
                    anchors { fill: parent; margins: 12 }
                    spacing: 8

                    // ── Row 1: dot + name + edit + trash ──────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            width: 9; height: 9; radius: 5
                            color: projCard.pColor
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: projCard.project.name || ""
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.SemiBold
                            color: _theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Edit button
                        Rectangle {
                            width: 26; height: 26; radius: Theme.radiusSm
                            color: cardEditArea.containsMouse ? _theme.bgHover : Qt.rgba(1,1,1,0.06)
                            opacity: projCard.hovered ? 1.0 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on color   { ColorAnimation  { duration: 100 } }
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

                        // Delete button
                        Rectangle {
                            width: 26; height: 26; radius: Theme.radiusSm
                            property real dr: parseInt(_theme.danger.slice(1,3), 16) / 255
                            property real dg: parseInt(_theme.danger.slice(3,5), 16) / 255
                            property real db: parseInt(_theme.danger.slice(5,7), 16) / 255
                            color: cardDeleteArea.containsMouse ? Qt.rgba(dr,dg,db,0.30) : Qt.rgba(dr,dg,db,0.14)
                            opacity: projCard.hovered ? 1.0 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                            Behavior on color   { ColorAnimation  { duration: 100 } }
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
                                onClicked: { if (service) service.deleteProject(projCard.project.id) }
                            }
                        }
                    }

                    // ── Description ───────────────────────────────────────
                    Text {
                        visible: (projCard.project.description || "") !== ""
                        text: projCard.project.description || ""
                        font.pixelSize: Theme.fontSm
                        color: _theme.textSecondary
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // ── Progress bar ──────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: _theme.bgHover
                        visible: projCard.total > 0

                        Rectangle {
                            width: parent.width * (projCard.total > 0 ? projCard.done / projCard.total : 0)
                            height: parent.height
                            radius: parent.radius
                            color: projCard.pColor
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }

                    // ── Tasks count + estimated time ──────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: projCard.done + "/" + projCard.total + " tasks"
                            font.pixelSize: Theme.fontSm
                            color: projCard.pColor
                        }

                        Item { Layout.fillWidth: true }

                        Image {
                            source: Theme.iconsPath + "clock.svg"
                            width: 12; height: 12
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.6
                            visible: true
                        }

                        Text {
                            text: root.formatMins(projCard.project.estimated_mins)
                            font.pixelSize: Theme.fontSm
                            color: _theme.textSecondary
                        }
                    }

                    // ── Dates ─────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: projCard.project.start_date || "-"
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }
                        Text {
                            text: "→"
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }
                        Text {
                            text: projCard.project.end_date || "-"
                            font.pixelSize: Theme.fontSm
                            color: _theme.textMuted
                        }
                    }
                }
            }
            } // Item wrapper
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

                    FocusDatePicker {
                        id: startDatePicker
                        Layout.fillWidth: true
                        value:   root._fieldStartDate
                        service: root.service
                        onValueChanged: root._fieldStartDate = value
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

                    FocusDatePicker {
                        id: endDatePicker
                        Layout.fillWidth: true
                        value:   root._fieldEndDate
                        service: root.service
                        onValueChanged: root._fieldEndDate = value
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
