import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Month heatmap: one square per day, intensity = completed tasks count.
Item {
    id: root

    property var service: null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border
    }
    property string _hoverText: ""

    implicitWidth:  140
    implicitHeight: 120

    // ── Header row: title + hover label ──────────────────────────────────────
    Item {
        id: headerRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 16

        Text {
            text: "Activity"
            font.pixelSize: Theme.fontMd
            color: _theme.textPrimary
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            visible: root._hoverText === ""
        }

        Text {
            text: root._hoverText
            font.pixelSize: Theme.fontSm
            color: _theme.textSecondary
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            visible: root._hoverText !== ""
        }
    }

    // ── Grid ──────────────────────────────────────────────────────────────
    Grid {
        id: grid
        anchors { top: headerRow.bottom; topMargin: 8; left: parent.left }
        columns: 7
        spacing: 4

        Repeater {
            model: daysInMonth()

            Rectangle {
                property int  dayNum:  modelData
                property int  count: {
                    if (!service) return 0
                    void service.tasks  // explicit dep so binding re-evaluates on task changes
                    return service.completedCountForDate(dayDate(dayNum))
                }
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
                    if (count === 0) return _theme.bgItem
                    var alpha = Math.min(1.0, 0.3 + count * 0.2)
                    return Qt.rgba(0.9, 0.22, 0.21, alpha)
                }
                border.color: isToday ? Qt.rgba(0.9, 0.22, 0.21, 0.8) : "transparent"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        var d = dayDate(parent.dayNum)
                        var monthNames = ["Jan","Fev","Mar","Abr","Mai","Jun",
                                          "Jul","Ago","Set","Out","Nov","Dez"]
                        var label = monthNames[d.getMonth()] + "-"
                            + String(d.getDate()).padStart(2, "0")
                            + "  " + parent.count + " concluída(s)"
                        root._hoverText = label
                    }
                    onExited: root._hoverText = ""
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
