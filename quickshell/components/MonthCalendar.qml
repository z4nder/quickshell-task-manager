import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

// Month calendar. Highlights today in red, shows dots for days with tasks.
Item {
    id: root

    property var service:      null
    property date selectedDate: new Date()

    signal dateSelected(date d)

    implicitWidth:  200
    implicitHeight: 220

    // Viewing month state
    property int viewYear:  selectedDate.getFullYear()
    property int viewMonth: selectedDate.getMonth()  // 0-based

    readonly property var monthNames: [
        "Janeiro","Fevereiro","Março","Abril","Maio","Junho",
        "Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"
    ]
    readonly property var dayNames: ["Mo","Tu","We","Th","Fr","Sa","Su"]

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // ── Month nav header ──────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "‹"
                font.pixelSize: 16
                color: Theme.textSecondary
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- }
                        else root.viewMonth--
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.viewMonth] + " " + root.viewYear
                font.pixelSize: Theme.fontMd
                font.weight: Font.Medium
                color: Theme.textPrimary
            }

            Text {
                text: "›"
                font.pixelSize: 16
                color: Theme.textSecondary
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ }
                        else root.viewMonth++
                    }
                }
            }
        }

        // ── Day of week headers ───────────────────────────────────────────
        Row {
            spacing: 0
            Repeater {
                model: root.dayNames
                Text {
                    width: (root.width) / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Theme.fontSm - 1
                    color: Theme.textMuted
                }
            }
        }

        // ── Day grid ─────────────────────────────────────────────────────
        Grid {
            id: dayGrid
            Layout.fillWidth: true
            columns: 7
            spacing: 0

            Repeater {
                model: calendarCells()

                delegate: Item {
                    width:  root.width / 7
                    height: 26

                    property int  cellDay:  modelData  // 0 = empty cell
                    property bool isToday: {
                        if (cellDay <= 0) return false
                        var t = new Date()
                        return t.getFullYear() === root.viewYear
                            && t.getMonth()    === root.viewMonth
                            && t.getDate()     === cellDay
                    }
                    property bool isSelected: {
                        if (cellDay <= 0) return false
                        return root.selectedDate.getFullYear() === root.viewYear
                            && root.selectedDate.getMonth()    === root.viewMonth
                            && root.selectedDate.getDate()     === cellDay
                    }
                    property int taskCount: {
                        if (cellDay <= 0 || !root.service) return 0
                        var d = new Date(root.viewYear, root.viewMonth, cellDay)
                        return root.service.tasksForDate(d).length
                    }

                    // Today circle background
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 22; radius: 11
                        color: isToday ? Theme.accent : (isSelected ? Theme.bgHover : "transparent")
                        visible: isToday || isSelected
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cellDay > 0 ? String(cellDay) : ""
                        font.pixelSize: Theme.fontSm
                        color: isToday ? Theme.textPrimary
                             : (cellDay > 0 ? Theme.textPrimary : "transparent")
                    }

                    // Task dot indicator
                    Rectangle {
                        visible: taskCount > 0 && !isToday
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: 4; height: 4; radius: 2
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: cellDay > 0
                        onClicked: {
                            root.selectedDate = new Date(root.viewYear, root.viewMonth, cellDay)
                            root.dateSelected(root.selectedDate)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Build array of day numbers for the calendar grid (0 = padding cell).
    function calendarCells() {
        var firstDay = new Date(viewYear, viewMonth, 1).getDay()  // 0=Sun
        // Convert Sunday-based to Monday-based
        var offset = (firstDay === 0) ? 6 : firstDay - 1
        var total  = new Date(viewYear, viewMonth + 1, 0).getDate()

        var cells = []
        for (var i = 0; i < offset; i++)  cells.push(0)
        for (var d = 1; d <= total; d++)  cells.push(d)
        // pad to full rows
        while (cells.length % 7 !== 0) cells.push(0)
        return cells
    }
}
