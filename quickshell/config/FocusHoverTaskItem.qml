import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Compact task row for the hover panel.
Rectangle {
    id: root

    property var    task:    null
    property var    service: null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
    }
    property bool   isActive: service && service.currentTask
                              && service.currentTask.id === task.id

    // Optimistic done state: show check immediately, send command after delay
    property bool _pendingDone: false

    signal playClicked()
    signal doneClicked()

    // Fires the actual backend command after 1s
    Timer {
        id: doneTimer
        interval: 1000
        repeat: false
        onTriggered: {
            root._pendingDone = false
            root.doneClicked()
        }
    }

    implicitHeight: 36
    color: (isActive || hoverArea.containsMouse) ? _theme.bgHover : "transparent"
    radius: Theme.radiusSm

    // Active left-edge accent bar
    Rectangle {
        width: 3
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 5; bottomMargin: 5 }
        radius: 2
        color: _theme.accent
        visible: isActive
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
        spacing: 6

        // Check toggle — empty circle when pending, filled accentAlt + checkmark when done
        Rectangle {
            width: 18; height: 18; radius: 9
            color: (task && task.completed) || root._pendingDone ? _theme.accentAlt : "transparent"
            border.color: (task && task.completed) || root._pendingDone
                          ? _theme.accentAlt
                          : (isActive ? _theme.accent : _theme.textMuted)
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 10; height: 10
                fillMode: Image.PreserveAspectFit
                visible: (task && task.completed) || root._pendingDone
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (task && task.completed) {
                        // Undone: no delay, act immediately
                        root.doneClicked()
                    } else if (!root._pendingDone) {
                        root._pendingDone = true
                        doneTimer.start()
                    } else {
                        // Second click cancels pending done
                        doneTimer.stop()
                        root._pendingDone = false
                    }
                }
            }
        }

        // Title — click selects/starts this task
        Text {
            text: task ? task.title : ""
            font.pixelSize: Theme.fontMd
            color: (task && task.completed) || root._pendingDone
                   ? _theme.textMuted : _theme.textPrimary
            elide: Text.ElideRight
            font.strikeout: (task && task.completed) || root._pendingDone
            Layout.fillWidth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !(task && task.completed) && !root._pendingDone
                onClicked: {
                    if (service && task) service.startSession(task.id)
                }
            }
        }

        // Project pill badge
        Rectangle {
            id: hoverPill
            property string pColor: (task && task.project_id && service)
                                    ? service.projectColor(task.project_id) : ""
            property string pName:  (task && task.project_id && service)
                                    ? service.projectName(task.project_id) : ""
            visible: pName !== "" && pColor !== ""
            implicitWidth:  hoverPillLabel.implicitWidth + 10
            implicitHeight: 16
            radius: 8
            color: Qt.rgba(
                parseInt(pColor.slice(1,3), 16) / 255,
                parseInt(pColor.slice(3,5), 16) / 255,
                parseInt(pColor.slice(5,7), 16) / 255,
                0.18
            )
            border.color: Qt.rgba(
                parseInt(pColor.slice(1,3), 16) / 255,
                parseInt(pColor.slice(3,5), 16) / 255,
                parseInt(pColor.slice(5,7), 16) / 255,
                0.55
            )
            border.width: 1

            Text {
                id: hoverPillLabel
                anchors.centerIn: parent
                text: hoverPill.pName
                font.pixelSize: Theme.fontSm - 1
                color: hoverPill.pColor
                elide: Text.ElideRight
            }
        }

        // Estimated mins badge
        Text {
            visible: task && task.estimated_mins
            text: task ? String(task.estimated_mins) + "m" : ""
            font.pixelSize: Theme.fontSm
            color: _theme.textMuted
        }

        // Play / pause button
        Rectangle {
            width: 24; height: 24
            radius: 12
            color: isActive ? _theme.accentDim : Qt.rgba(1, 1, 1, 0.08)
            border.color: isActive ? _theme.accent : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            visible: !(task && task.completed) && !root._pendingDone

            Image {
                anchors.centerIn: parent
                source: {
                    if (!isActive) return Theme.iconsPath + "play.svg"
                    return service.sessionPaused ? Theme.iconsPath + "play-accent.svg"
                                                 : Theme.iconsPath + "pause.svg"
                }
                width: 11; height: 11
                fillMode: Image.PreserveAspectFit
                opacity: 0.9
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.playClicked()
            }
        }

    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
