import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "FocusTheme.js" as Theme

// Month heatmap: one square per day, intensity = completed tasks count.
Item {
    id: root

    property var service: null

    implicitWidth:  140
    implicitHeight: 120

    // ── Header ────────────────────────────────────────────────────────────
    Text {
        id: header
        text: "Activity"
        font.pixelSize: Theme.fontMd
        color: Theme.textPrimary
        anchors { top: parent.top; left: parent.left }
    }

    // ── Grid ──────────────────────────────────────────────────────────────
    Grid {
        id: grid
        anchors { top: header.bottom; topMargin: 8; left: parent.left }
        columns: 7
        spacing: 4

        Repeater {
            model: daysInMonth()

            Rectangle {
                property int  dayNum:  modelData
                property int  count:   service ? service.completedCountForDate(dayDate(dayNum)) : 0
                property bool isToday: {
                    var d = dayDate(dayNum)
                    var t = new Date()
                    return d.getFullYear() === t.getFullYear()
                        && d.getMonth()    === t.getMonth()
                        && d.getDate()     === t.getDate()
                }

                width: 14; height: 14
                radius: 3
                color: {
                    if (isToday && count === 0) return Qt.rgba(0.9, 0.22, 0.21, 0.5)
                    if (count === 0) return Theme.bgItem
                    // intensity: 1 task → dim red, 4+ → full red
                    var alpha = Math.min(1.0, 0.3 + count * 0.2)
                    return Qt.rgba(0.9, 0.22, 0.21, alpha)
                }

                // Tooltip on hover
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    ToolTip.visible: containsMouse
                    ToolTip.text: {
                        var d = dayDate(parent.dayNum)
                        return Qt.formatDate(d, "dd/MM") + ": " + parent.count + " concluída(s)"
                    }
                    ToolTip.delay: 300
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function daysInMonth() {
        var now = new Date()
        var total = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
        var arr = []
        for (var i = 1; i <= total; i++) arr.push(i)
        return arr
    }

    function dayDate(day) {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), day)
    }
}
