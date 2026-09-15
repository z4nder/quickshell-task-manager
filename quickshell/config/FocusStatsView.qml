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

    // ── State ─────────────────────────────────────────────────────────────────
    property var    _scope:      null   // null = global, int = project id
    property string _period:     "month" // "month" | "3months" | "6months" | "year"
    property bool   _dropdownOpen: false

    // ── Range computation (reactive readonly) ─────────────────────────────────
    readonly property string _rangeStart: {
        var today = new Date()
        var end = Qt.formatDate(today, "yyyy-MM-dd")
        if (_scope !== null) {
            var proj = null
            var projs = service ? service.projects : []
            for (var i = 0; i < projs.length; i++) {
                if (projs[i].id === _scope) { proj = projs[i]; break }
            }
            return (proj && proj.start_date) ? proj.start_date : ""
        }
        if (_period === "month") {
            var d = new Date(today.getFullYear(), today.getMonth(), 1)
            return Qt.formatDate(d, "yyyy-MM-dd")
        } else if (_period === "3months") {
            var d2 = new Date(today); d2.setDate(d2.getDate() - 90)
            return Qt.formatDate(d2, "yyyy-MM-dd")
        } else if (_period === "6months") {
            var d3 = new Date(today); d3.setDate(d3.getDate() - 180)
            return Qt.formatDate(d3, "yyyy-MM-dd")
        } else {
            var d4 = new Date(today.getFullYear(), 0, 1)
            return Qt.formatDate(d4, "yyyy-MM-dd")
        }
    }

    readonly property string _rangeEnd: {
        var today = new Date()
        var end = Qt.formatDate(today, "yyyy-MM-dd")
        if (_scope !== null) {
            var proj = null
            var projs = service ? service.projects : []
            for (var i = 0; i < projs.length; i++) {
                if (projs[i].id === _scope) { proj = projs[i]; break }
            }
            return (proj && proj.end_date) ? proj.end_date : end
        }
        return end
    }

    // ── Filtered tasks ────────────────────────────────────────────────────────
    readonly property var _filteredTasks: {
        var base = service ? service.tasks : []
        if (_scope !== null)
            base = base.filter(function(t) { return t.project_id === _scope })
        if (_rangeStart) {
            base = base.filter(function(t) {
                if (!t.scheduled_date) return true
                return t.scheduled_date >= _rangeStart && t.scheduled_date <= _rangeEnd
            })
        }
        return base
    }

    readonly property int _totalSecs: {
        var s = 0
        for (var i = 0; i < _filteredTasks.length; i++) s += (_filteredTasks[i].elapsed_secs || 0)
        return s
    }
    readonly property int _doneTasks: {
        var n = 0
        for (var i = 0; i < _filteredTasks.length; i++) if (_filteredTasks[i].completed) n++
        return n
    }
    readonly property int _openTasks: _filteredTasks.length - _doneTasks
    readonly property int _tasksWithTime: {
        var n = 0
        for (var i = 0; i < _filteredTasks.length; i++) if ((_filteredTasks[i].elapsed_secs || 0) > 0) n++
        return n
    }
    readonly property int _avgSecs: _tasksWithTime > 0 ? Math.round(_totalSecs / _tasksWithTime) : 0

    readonly property real _completionPct: _filteredTasks.length > 0
        ? Math.min(1.0, _tasksWithTime / _filteredTasks.length)
        : 0.0

    // ── Helpers ───────────────────────────────────────────────────────────────
    function formatTimeStat(secs) {
        if (!secs || secs <= 0) return "0m"
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        if (h > 0) return h + "h " + (m > 0 ? m + "m" : "")
        return m + "m"
    }

    function _formatRangeDate(dateStr) {
        if (!dateStr) return "—"
        var d = new Date(dateStr + "T00:00:00")
        return Qt.formatDate(d, "d MMM yyyy")
    }

    function _scopeLabel() {
        if (_scope === null) return "Global"
        var projs = service ? service.projects : []
        for (var i = 0; i < projs.length; i++)
            if (projs[i].id === _scope) return projs[i].name
        return "Global"
    }

    // ── Chart data ────────────────────────────────────────────────────────────
    readonly property var _chartData: {
        var tasks = _filteredTasks
        var groups = []
        if (_scope === null) {
            // Group by project
            var map = {}
            var projs = service ? service.projects : []
            for (var i = 0; i < tasks.length; i++) {
                var t = tasks[i]
                var secs = t.elapsed_secs || 0
                if (secs <= 0) continue
                var key = t.project_id !== null && t.project_id !== undefined ? String(t.project_id) : "__none__"
                if (!map[key]) map[key] = 0
                map[key] += secs
            }
            var total = _totalSecs
            var sliceColors = [_theme.accent, _theme.accentAlt, _theme.warning,
                               "#e53935", "#7986cb", "#4db6ac", "#ff8a65", "#a1887f"]
            var colorIdx = 0
            for (var key2 in map) {
                var label = "Sem projeto"
                var color = _theme.textMuted
                if (key2 !== "__none__") {
                    var pid = parseInt(key2)
                    for (var j = 0; j < projs.length; j++) {
                        if (projs[j].id === pid) {
                            label = projs[j].name
                            color = projs[j].color || sliceColors[colorIdx % sliceColors.length]
                            colorIdx++
                            break
                        }
                    }
                }
                groups.push({
                    label: label,
                    color: color,
                    secs:  map[key2],
                    pct:   total > 0 ? Math.round(map[key2] / total * 100) : 0
                })
            }
        } else {
            // Group by individual task
            var altColors = [_theme.accent, _theme.accentAlt, _theme.warning,
                             "#e53935", "#7986cb", "#4db6ac", "#ff8a65", "#a1887f"]
            var total2 = _totalSecs
            var filtered = tasks.filter(function(t) { return (t.elapsed_secs || 0) > 0 })
            for (var k = 0; k < filtered.length; k++) {
                var tk = filtered[k]
                groups.push({
                    label: tk.title,
                    color: altColors[k % altColors.length],
                    secs:  tk.elapsed_secs || 0,
                    pct:   total2 > 0 ? Math.round((tk.elapsed_secs || 0) / total2 * 100) : 0
                })
            }
        }
        // Sort descending by secs
        groups.sort(function(a, b) { return b.secs - a.secs })
        return groups
    }

    // ── Recent tasks (top 8 by elapsed_secs desc) ─────────────────────────────
    readonly property var _recentTasks: {
        var copy = _filteredTasks.slice()
        copy.sort(function(a, b) { return (b.elapsed_secs || 0) - (a.elapsed_secs || 0) })
        return copy.slice(0, 8)
    }

    // ── Project color lookup ──────────────────────────────────────────────────
    function _projectColor(projectId) {
        if (projectId === null || projectId === undefined) return _theme.textMuted
        var projs = service ? service.projects : []
        for (var i = 0; i < projs.length; i++)
            if (projs[i].id === projectId) return projs[i].color || _theme.textMuted
        return _theme.textMuted
    }

    // ── Layout ────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Header row ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Estatísticas"
                font.pixelSize: Theme.fontLg
                font.weight: Font.DemiBold
                color: _theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            // Period chips (global only)
            RowLayout {
                visible: _scope === null
                spacing: 4

                Repeater {
                    model: [
                        { key: "month",   label: "Este mês" },
                        { key: "3months", label: "3 meses"  },
                        { key: "6months", label: "6 meses"  },
                        { key: "year",    label: "Ano"       }
                    ]
                    delegate: Rectangle {
                        implicitWidth:  periodLbl.implicitWidth + 16
                        implicitHeight: 26
                        radius:         Theme.radiusSm
                        color:          _period === modelData.key ? _theme.accent : _theme.bgItem
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                            id: periodLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Theme.fontSm
                            color: _period === modelData.key ? "#ffffff" : _theme.textSecondary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: _period = modelData.key
                        }
                    }
                }
            }

            // Scope selector pill
            Item {
                id: scopeSelector
                implicitWidth:  scopeRow.implicitWidth + 24
                implicitHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius:       Theme.radiusSm
                    color:        scopeSelectorArea.containsMouse ? _theme.bgHover : _theme.bgItem
                    border.color: _theme.border
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        id: scopeRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: _scopeLabel()
                            font.pixelSize: Theme.fontSm
                            color: _theme.textPrimary
                        }
                        Text {
                            text: _dropdownOpen ? "▲" : "▼"
                            font.pixelSize: 9
                            color: _theme.textMuted
                        }
                    }

                    MouseArea {
                        id: scopeSelectorArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: _dropdownOpen = !_dropdownOpen
                    }
                }

            }
        }

        // ── Date range label ──────────────────────────────────────────────────
        Text {
            text: _rangeStart ? (_formatRangeDate(_rangeStart) + " → " + _formatRangeDate(_rangeEnd)) : "Todos os períodos"
            font.pixelSize: Theme.fontSm
            color: _theme.textMuted
        }

        // ── Progress bar ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Progresso (" + _tasksWithTime + " de " + _filteredTasks.length + " tarefas)"
                    font.pixelSize: Theme.fontSm
                    color: _theme.textSecondary
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Math.round(_completionPct * 100) + "%"
                    font.pixelSize: Theme.fontSm
                    color: _theme.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: _theme.bgItem

                Rectangle {
                    width:  parent.width * _completionPct
                    height: parent.height
                    radius: parent.radius
                    color:  _theme.accent
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }

        // ── Stat cards ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Tempo total
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                color:  _theme.bgItem
                radius: Theme.radiusSm

                ColumnLayout {
                    id: cardCol1
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 4

                    Text {
                        text: "Tempo total"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textMuted
                    }
                    Text {
                        text: formatTimeStat(_totalSecs)
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.DemiBold
                        color: _theme.accent
                    }
                }
            }

            // Média / tarefa
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                color:  _theme.bgItem
                radius: Theme.radiusSm

                ColumnLayout {
                    id: cardCol2
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 4

                    Text {
                        text: "Média/tarefa"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textMuted
                    }
                    Text {
                        text: formatTimeStat(_avgSecs)
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.DemiBold
                        color: _theme.accentAlt
                    }
                }
            }

            // Done / open
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 64
                color:  _theme.bgItem
                radius: Theme.radiusSm

                ColumnLayout {
                    id: cardCol3
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 4

                    Text {
                        text: "Concluídas"
                        font.pixelSize: Theme.fontSm
                        color: _theme.textMuted
                    }
                    RowLayout {
                        spacing: 6
                        Text {
                            text: _doneTasks + " ✓"
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.DemiBold
                            color: _theme.accent
                        }
                        Text {
                            text: "/ " + _openTasks + " ○"
                            font.pixelSize: Theme.fontMd
                            font.weight: Font.DemiBold
                            color: _theme.textMuted
                        }
                    }
                }
            }
        }

        // ── Bottom section: recent tasks + donut ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            Layout.maximumHeight: 220
            spacing: 10

            // Recent tasks list
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: parent.width * 0.45
                color:  _theme.bgItem
                radius: Theme.radiusSm
                clip:   true

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 6

                    Text {
                        text: "Tarefas recentes"
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.DemiBold
                        color: _theme.textSecondary
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: _recentTasks
                                delegate: Rectangle {
                                    width:         parent ? parent.width : 0
                                    implicitHeight: 30
                                    color:         recentTaskArea.containsMouse ? _theme.bgHover : "transparent"
                                    radius:        Theme.radiusSm
                                    Behavior on color { ColorAnimation { duration: 80 } }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                        spacing: 6

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: _projectColor(modelData.project_id)
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            font.pixelSize: Theme.fontSm
                                            color: modelData.completed ? _theme.textMuted : _theme.textPrimary
                                            elide: Text.ElideRight
                                            font.strikeout: modelData.completed
                                        }

                                        Text {
                                            text: formatTimeStat(modelData.elapsed_secs || 0)
                                            font.pixelSize: Theme.fontSm
                                            color: (modelData.elapsed_secs || 0) > 0 ? _theme.accent : _theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: recentTaskArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }

                            // Empty state
                            Text {
                                visible: _recentTasks.length === 0
                                Layout.fillWidth: true
                                text: "Nenhuma tarefa no período"
                                font.pixelSize: Theme.fontSm
                                color: _theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 20
                            }
                        }
                    }
                }
            }

            // Donut chart + legend
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth:  true
                color:  _theme.bgItem
                radius: Theme.radiusSm
                clip:   true

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 6

                    Text {
                        text: _scope === null ? "Tempo por projeto" : "Tempo por tarefa"
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.DemiBold
                        color: _theme.textSecondary
                    }

                    // Canvas donut
                    Canvas {
                        id: donutCanvas
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(parent.width * 0.6, 160)

                        property var chartData: _chartData
                        property string centerText: root.formatTimeStat(root._totalSecs)
                        property color  centerColor: _theme.textPrimary
                        property color  mutedColor:  _theme.textMuted
                        property color  bgColor:     _theme.bgItem

                        onChartDataChanged:   requestPaint()
                        onCenterTextChanged:  requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            var cx = width / 2
                            var cy = height / 2
                            var outerR = Math.min(cx, cy) - 4
                            var innerR = outerR * 0.52
                            var gap    = 0.02

                            var data = chartData
                            if (!data || data.length === 0) {
                                // Empty ring
                                ctx.beginPath()
                                ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
                                ctx.arc(cx, cy, innerR, Math.PI * 2, 0, true)
                                ctx.fillStyle = mutedColor
                                ctx.globalAlpha = 0.15
                                ctx.fill()
                                ctx.globalAlpha = 1.0

                                ctx.fillStyle = centerColor
                                ctx.font = "bold 13px sans-serif"
                                ctx.textAlign = "center"
                                ctx.textBaseline = "middle"
                                ctx.fillText("0m", cx, cy)
                                return
                            }

                            // Calculate total to normalise
                            var total = 0
                            for (var i = 0; i < data.length; i++) total += data[i].secs
                            if (total <= 0) return

                            var startAngle = -Math.PI / 2

                            for (var j = 0; j < data.length; j++) {
                                var sweep = (data[j].secs / total) * (Math.PI * 2) - gap
                                if (sweep <= 0) continue

                                ctx.beginPath()
                                ctx.moveTo(cx + innerR * Math.cos(startAngle + gap / 2),
                                           cy + innerR * Math.sin(startAngle + gap / 2))
                                ctx.arc(cx, cy, outerR, startAngle + gap / 2, startAngle + gap / 2 + sweep)
                                ctx.arc(cx, cy, innerR, startAngle + gap / 2 + sweep, startAngle + gap / 2, true)
                                ctx.closePath()
                                ctx.fillStyle = data[j].color
                                ctx.fill()

                                startAngle += sweep + gap
                            }

                            // Center hole fill
                            ctx.beginPath()
                            ctx.arc(cx, cy, innerR - 1, 0, Math.PI * 2)
                            ctx.fillStyle = bgColor
                            ctx.fill()

                            // Center text
                            ctx.fillStyle = centerColor
                            ctx.font = "bold 13px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"
                            ctx.fillText(centerText, cx, cy)
                        }

                    }

                    // Legend
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: parent.width
                            spacing: 3

                            Repeater {
                                model: _chartData
                                delegate: RowLayout {
                                    width: parent ? parent.width : 0
                                    spacing: 6

                                    Rectangle {
                                        width: 10; height: 10; radius: 2
                                        color: modelData.color
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSm - 1
                                        color: _theme.textSecondary
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData.pct + "%"
                                        font.pixelSize: Theme.fontSm - 1
                                        color: _theme.textMuted
                                    }
                                }
                            }

                            Text {
                                visible: _chartData.length === 0
                                Layout.fillWidth: true
                                text: "Sem dados no período"
                                font.pixelSize: Theme.fontSm
                                color: _theme.textMuted
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ── Scope dropdown (root-level so z works properly) ───────────────────────
    Rectangle {
        id: scopeDropdown
        visible: _dropdownOpen
        z: 999
        x: root.mapFromItem(scopeSelector, 0, 0).x + scopeSelector.width - width
        y: root.mapFromItem(scopeSelector, 0, 0).y + scopeSelector.height + 2
        width: Math.max(scopeSelector.width, 160)
        height: dropdownCol.implicitHeight + 8
        color: _theme.bgPanel
        border.color: _theme.border
        border.width: 1
        radius: Theme.radiusSm

        ColumnLayout {
            id: dropdownCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
            spacing: 1

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSm
                color: globalOptArea.containsMouse ? _theme.bgHover
                     : (_scope === null ? _theme.accentDim : "transparent")
                Text {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: "Global"
                    font.pixelSize: Theme.fontSm
                    color: _scope === null ? _theme.accent : _theme.textPrimary
                }
                MouseArea {
                    id: globalOptArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { _scope = null; _dropdownOpen = false }
                }
            }

            Repeater {
                model: service ? service.projects : []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Theme.radiusSm
                    color: projOptArea.containsMouse ? _theme.bgHover
                         : (_scope === modelData.id ? _theme.accentDim : "transparent")
                    RowLayout {
                        anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 6
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.color || _theme.textMuted }
                        Text {
                            text: modelData.name
                            font.pixelSize: Theme.fontSm
                            color: _scope === modelData.id ? _theme.accent : _theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    MouseArea {
                        id: projOptArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { _scope = modelData.id; _dropdownOpen = false }
                    }
                }
            }
        }
    }

    // Close dropdown when clicking outside
    MouseArea {
        anchors.fill: parent
        z: _dropdownOpen ? 50 : -1
        visible: _dropdownOpen
        onClicked: _dropdownOpen = false
    }
}
