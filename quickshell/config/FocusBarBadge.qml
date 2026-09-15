import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Bar badge with animated border trail.
// The trail fills clockwise based on `service.progress` (0.0–1.0).
Item {
    id: root

    property var service: null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
    }
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
            if (p >= 1.0) return _theme.accent
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

            var lw  = 2.5
            var W   = width  - lw
            var H   = height - lw
            var r   = H / 2
            var off = lw / 2

            var cxL = off + r
            var cxR = off + W - r
            var cy  = off + r

            var arcLen      = Math.PI * r
            var straightLen = W - 2 * r
            var totalPerim  = 2 * arcLen + straightLen

            // Draw the full U path (background track, always visible)
            function drawU(color) {
                ctx.strokeStyle = color
                ctx.lineWidth   = lw
                ctx.lineCap     = "round"
                ctx.beginPath()
                ctx.arc(cxL, cy, r, -Math.PI / 2, Math.PI / 2, true)   // left semicircle ↓
                ctx.lineTo(cxR, off + H)                                 // bottom →
                ctx.arc(cxR, cy, r, Math.PI / 2, -Math.PI / 2, true)   // right semicircle ↑
                ctx.stroke()
            }

            // 1. Background track
            drawU("#2a2a2e")

            if (!progress || progress <= 0) return

            // 2. Progress trail — draw partial path by clipping a rect
            var filled = progress * totalPerim
            var rem    = filled

            ctx.strokeStyle = trailColor()
            ctx.lineWidth   = lw
            ctx.lineCap     = "round"

            function arcSeg(cx, startAngle, len) {
                if (rem <= 0) return
                var t = Math.min(1, rem / len)
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, startAngle - t * Math.PI, true)
                ctx.stroke()
                rem -= len * t
            }

            function seg(x1, y1, x2, y2, len) {
                if (rem <= 0) return
                var t = Math.min(1, rem / len)
                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x1 + t * (x2 - x1), y1 + t * (y2 - y1))
                ctx.stroke()
                rem -= len * t
            }

            arcSeg(cxL, -Math.PI / 2, arcLen)          // left semicircle ↓
            seg(cxL, off + H, cxR, off + H, straightLen) // bottom →
            arcSeg(cxR,  Math.PI / 2, arcLen)           // right semicircle ↑
        }
    }

    // ── Background ────────────────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; margins: 2 }
        color: _theme.bg
        radius: height / 2
    }

    // ── Content ───────────────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 0

        // Timer section: status dot + elapsed time
        RowLayout {
            spacing: 6
            Layout.preferredWidth: 76

            // Status dot
            Rectangle {
                width: 6; height: 6; radius: 3
                color: {
                    if (!service || !service.sessionActive) return _theme.textMuted
                    return service.sessionPaused ? Qt.rgba(0.9, 0.6, 0, 1) : _theme.accent
                }
            }

            // Elapsed time
            Text {
                text: service ? service.formatTime(service.elapsedSecs) : "00:00"
                font.pixelSize: Theme.fontMd
                font.family:    "monospace"
                color: _theme.textPrimary
                font.weight: Font.Medium
            }
        }

        // Separator
        Rectangle {
            width: 1; height: 12
            color: _theme.border
            Layout.leftMargin: 4
            Layout.rightMargin: 8
        }

        // Task name — elided
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
                color: (service && service.sessionActive)
                       ? _theme.textSecondary : _theme.textMuted
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
