import QtQuick
import QtQuick.Layouts
import "../Theme.js" as Theme

// Bar badge with animated border trail.
// The trail fills clockwise based on `service.progress` (0.0–1.0).
Item {
    id: root

    property var service: null
    signal hovered(bool isHovered)
    signal expandClicked()

    implicitWidth:  320
    implicitHeight: 28

    // ── Border trail canvas ───────────────────────────────────────────────
    Canvas {
        id: trail
        anchors.fill: parent

        property real progress: service ? service.progress : 0
        onProgressChanged: requestPaint()

        function trailColor() {
            var p = progress
            if (p >= 1.0) return Theme.accent
            if (p > 0.75) {
                // interpolate orange → red
                return Qt.rgba(0.9, 0.3 - 0.1 * ((p - 0.75) * 4), 0.0, 1)
            }
            if (p > 0.5) {
                // yellow → orange
                return Qt.rgba(0.9, 0.6 - 0.3 * ((p - 0.5) * 4), 0.0, 1)
            }
            // green → yellow
            return Qt.rgba(0.2 + 0.7 * (p * 2), 0.85, 0.0, 1)
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!progress || progress <= 0) return

            var lw   = 2
            var off  = lw / 2
            var W    = width  - lw
            var H    = height - lw

            var totalPerim = 2 * (W + H)
            var filled     = progress * totalPerim

            var segs = [
                { x1: off, y1: off,     x2: W + off, y2: off },         // top →
                { x1: W + off, y1: off, x2: W + off, y2: H + off },     // right ↓
                { x1: W + off, y1: H + off, x2: off, y2: H + off },     // bottom ←
                { x1: off, y1: H + off, x2: off,     y2: off },         // left ↑
            ]
            var lens = [W, H, W, H]

            ctx.strokeStyle = trailColor()
            ctx.lineWidth   = lw
            ctx.lineCap     = "square"

            var rem = filled
            for (var i = 0; i < segs.length && rem > 0; i++) {
                var s   = segs[i]
                var len = lens[i]
                var t   = Math.min(1, rem / len)
                ctx.beginPath()
                ctx.moveTo(s.x1, s.y1)
                ctx.lineTo(s.x1 + t * (s.x2 - s.x1), s.y1 + t * (s.y2 - s.y1))
                ctx.stroke()
                rem -= len * t
            }
        }
    }

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; margins: 2 }
        color: Theme.bg
    }

    // ── Content ───────────────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        // Clock icon
        Text {
            text: "○"
            font.pixelSize: Theme.fontMd
            color: service && service.sessionActive
                   ? (service.sessionPaused ? Qt.rgba(0.9, 0.6, 0, 1) : Theme.accent)
                   : Theme.textSecondary
        }

        // Elapsed time
        Text {
            text: service ? service.formatTime(service.elapsedSecs) : "00:00"
            font.pixelSize: Theme.fontMd
            font.family:    "monospace"
            color: Theme.textPrimary
            Layout.minimumWidth: 42
        }

        // Separator
        Rectangle {
            width: 1; height: 14
            color: Theme.border
        }

        // Task name — scrolling marquee when long
        Item {
            Layout.fillWidth: true
            implicitHeight:   parent.height
            clip: true

            Text {
                id: taskLabel
                text: {
                    if (!service || !service.sessionActive || !service.currentTask)
                        return "Nenhuma tarefa ativa"
                    return service.currentTask.title
                }
                font.pixelSize: Theme.fontSm
                color: Theme.textSecondary
                elide: Text.ElideRight
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ── Hover detection ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered(true)
        onExited:  root.hovered(false)
    }
}
