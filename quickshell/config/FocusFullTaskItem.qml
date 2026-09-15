import QtQuick
import QtQuick.Layouts
import "FocusTheme.js" as Theme

// Full task row for the FocusAppScreen (more buttons than hover variant).
Rectangle {
    id: root

    property var  task:      null
    property var  service:   null
    readonly property var _theme: (service && service.themeData) ? service.themeData : {
        bg: Theme.bg, bgPanel: Theme.bgPanel, bgItem: Theme.bgItem, bgHover: Theme.bgHover,
        textPrimary: Theme.textPrimary, textSecondary: Theme.textSecondary, textMuted: Theme.textMuted,
        accent: Theme.accent, accentDim: Theme.accentDim, border: Theme.border,
        accentAlt: Theme.accentAlt, danger: Theme.danger, warning: Theme.warning
    }
    property bool isActive:  service && service.currentTask
                             && service.currentTask.id === task.id

    // Optimistic done state: show check immediately, send command after delay
    property bool _pendingDone: false

    signal doneClicked()
    signal deleteClicked()
    signal playClicked()
    signal editClicked()

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

    implicitHeight: 40
    radius: Theme.radiusSm
    color: (isActive || hArea.containsMouse) ? _theme.bgHover : "transparent"

    // Active left-edge accent bar
    Rectangle {
        width: 3
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 6; bottomMargin: 6 }
        radius: 2
        color: _theme.accent
        visible: isActive
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
        spacing: 8

        // Circle checkbox — empty circle when pending, filled accentAlt + checkmark when done
        Rectangle {
            width: 20; height: 20; radius: 10
            color: (task && task.completed) || root._pendingDone ? _theme.accentAlt : "transparent"
            border.color: (task && task.completed) || root._pendingDone
                          ? _theme.accentAlt
                          : (isActive ? _theme.accent : _theme.textMuted)
            border.width: 1.5

            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "check.svg"
                width: 11; height: 11
                fillMode: Image.PreserveAspectFit
                visible: (task && task.completed) || root._pendingDone
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (task && task.completed) {
                        root.doneClicked()
                    } else if (!root._pendingDone) {
                        root._pendingDone = true
                        doneTimer.start()
                    } else {
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
            color: (task && task.completed) || root._pendingDone ? _theme.textMuted : _theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
            font.strikeout: (task && task.completed) || root._pendingDone

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
            id: projectPill
            property string pColor: (task && task.project_id && service)
                                    ? service.projectColor(task.project_id) : ""
            property string pName:  (task && task.project_id && service)
                                    ? service.projectName(task.project_id) : ""
            visible: pName !== "" && pColor !== ""
            implicitWidth:  pillLabel.implicitWidth + 12
            implicitHeight: 18
            radius: 9
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
                id: pillLabel
                anchors.centerIn: parent
                text: projectPill.pName
                font.pixelSize: Theme.fontSm
                color: projectPill.pColor
                elide: Text.ElideRight
            }
        }

        // Estimated mins badge
        Rectangle {
            visible: task && task.estimated_mins
            color: _theme.bgItem
            radius: Theme.radiusSm
            implicitWidth: minsLabel.implicitWidth + 10
            implicitHeight: 18

            Text {
                id: minsLabel
                anchors.centerIn: parent
                text: task ? String(task.estimated_mins) + "m" : ""
                font.pixelSize: Theme.fontSm
                color: _theme.textSecondary
            }
        }

        // Play / Pause button
        Rectangle {
            width: 26; height: 26; radius: 13
            color: isActive ? _theme.accentDim : _theme.accent
            visible: !(task && task.completed) && !root._pendingDone
            opacity: hArea.containsMouse || isActive ? 1.0 : 0.75

            Image {
                anchors.centerIn: parent
                source: {
                    if (!isActive) return Theme.iconsPath + "play.svg"
                    return service.sessionPaused ? Theme.iconsPath + "play-accent.svg"
                                                 : Theme.iconsPath + "pause.svg"
                }
                width: 12; height: 12
                fillMode: Image.PreserveAspectFit
            }

            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playClicked() }
        }

        // Edit button
        Rectangle {
            width: 26; height: 26; radius: Theme.radiusSm
            color: editIconArea.containsMouse ? _theme.bgHover : Qt.rgba(1,1,1,0.06)
            opacity: hArea.containsMouse ? 1.0 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color   { ColorAnimation  { duration: 100 } }
            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "pencil-square.svg"
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
                opacity: editIconArea.containsMouse ? 1.0 : 0.75
            }
            MouseArea {
                id: editIconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editClicked()
            }
        }

        // Delete button — always danger-tinted when row is hovered
        Rectangle {
            id: deleteBtn
            width: 26; height: 26; radius: Theme.radiusSm
            property real dr: parseInt(_theme.danger.slice(1,3), 16) / 255
            property real dg: parseInt(_theme.danger.slice(3,5), 16) / 255
            property real db: parseInt(_theme.danger.slice(5,7), 16) / 255
            color: deleteIconArea.containsMouse
                ? Qt.rgba(dr, dg, db, 0.30)
                : Qt.rgba(dr, dg, db, 0.14)
            opacity: hArea.containsMouse ? 1.0 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Behavior on color   { ColorAnimation  { duration: 100 } }
            Image {
                anchors.centerIn: parent
                source: Theme.iconsPath + "trash.svg"
                width: 14; height: 14
                fillMode: Image.PreserveAspectFit
                opacity: deleteIconArea.containsMouse ? 1.0 : 0.85
            }
            MouseArea {
                id: deleteIconArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.deleteClicked()
            }
        }
    }

    MouseArea {
        id: hArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
