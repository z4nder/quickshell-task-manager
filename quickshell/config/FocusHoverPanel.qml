import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import "FocusTheme.js" as Theme

Rectangle {
    id: root

    property var service: null
    signal expand()
    signal panelHoveredChanged(bool h)

    implicitWidth:  460
    implicitHeight: 220
    color:          Theme.bgPanel
    radius:         Theme.radiusLg

    layer.enabled: true
    layer.effect: null

    // ── Task data (ListModel so DelegateModel can do efficient moves) ─────
    ListModel { id: taskListModel }

    property bool _dragging: false
    // Tracks the current visual order as an array of taskIds (updated on each DropArea move)
    property var _visualOrder: []

    function _syncTasks() {
        if (root._dragging) return
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
        var all = root.service ? root.service.tasks : []
        var tasks = all.filter(function(t) {
            return !t.scheduled_date || t.scheduled_date === today
        })
        taskListModel.clear()
        root._visualOrder = []
        for (var i = 0; i < tasks.length; i++) {
            var t = tasks[i]
            taskListModel.append({
                taskId:        t.id,
                taskTitle:     t.title      || "",
                taskCompleted: t.completed  || false,
                taskEstMins:   t.estimated_mins || 0,
                taskElapsed:   t.elapsed_secs   || 0
            })
            root._visualOrder.push(t.id)
        }
    }

    Connections {
        target: root.service
        function onTasksChanged() { root._syncTasks() }
    }
    Component.onCompleted: _syncTasks()

    // ── DelegateModel wraps ListModel for smooth reorder moves ────────────
    DelegateModel {
        id: visualModel
        model: taskListModel

        delegate: Item {
            id: delegateRoot
            width:  todoList.width
            height: 36

            // Tracks this item's live position in the visual model
            property int visualIndex: DelegateModel.itemsIndex

            // ── Draggable content ─────────────────────────────────────────
            Item {
                id: dragContent
                width:  delegateRoot.width
                height: delegateRoot.height
                anchors.horizontalCenter: parent.horizontalCenter

                Drag.active:   dragArea.drag.active
                Drag.source:   delegateRoot
                Drag.hotSpot.x: width  / 2
                Drag.hotSpot.y: height / 2

                // Reparent to ListView when dragging so it can float freely
                states: State {
                    when: dragContent.Drag.active
                    ParentChange {
                        target: dragContent
                        parent: todoList
                    }
                    AnchorChanges {
                        target: dragContent
                        anchors.horizontalCenter: undefined
                    }
                }

                // Elevated background while dragging
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSm
                    color: dragContent.Drag.active
                        ? Qt.rgba(1, 1, 1, 0.06)
                        : "transparent"
                    border.color: dragContent.Drag.active
                        ? Qt.rgba(1, 1, 1, 0.10)
                        : "transparent"
                    border.width: 1
                }

                // Scale up slightly when lifted
                scale: dragContent.Drag.active ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                FocusHoverTaskItem {
                    anchors.fill: parent
                    task: ({
                        id:             taskId,
                        title:          taskTitle,
                        completed:      taskCompleted,
                        estimated_mins: taskEstMins > 0 ? taskEstMins : null,
                        elapsed_secs:   taskElapsed
                    })
                    service: root.service
                    opacity: dragContent.Drag.active ? 0.75 : 1.0

                    onPlayClicked: {
                        if (!service) return
                        if (service.sessionActive && service.currentTask
                                && service.currentTask.id === taskId) {
                            if (service.sessionPaused) service.resumeSession()
                            else                       service.pauseSession()
                        } else {
                            service.startSession(taskId)
                        }
                    }
                    onDoneClicked: {
                        if (!service) return
                        if (taskCompleted) service.undoneTask(taskId)
                        else              service.doneTask(taskId)
                    }
                }
            }

            // ── Drop zone — triggers reorder when another item enters ─────
            DropArea {
                anchors { fill: parent; margins: 2 }
                onEntered: function(drag) {
                    var from = drag.source.visualIndex
                    var to   = delegateRoot.visualIndex
                    if (from === to) return
                    root._dragging = true
                    visualModel.items.move(from, to, 1)
                    // Keep _visualOrder in sync with the visual move
                    var order = root._visualOrder.slice()
                    var moved = order.splice(from, 1)[0]
                    order.splice(to, 0, moved)
                    root._visualOrder = order
                }
            }

            // ── Drag initiator ────────────────────────────────────────────
            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target:  dragContent
                drag.axis:    Drag.YAxis
                propagateComposedEvents: true
                cursorShape:  Qt.PointingHandCursor

                onReleased: {
                    dragContent.Drag.drop()
                    if (root._dragging && root.service) {
                        var ids = root._visualOrder.slice()
                        // Build name lookup from taskListModel (still has all items)
                        var names = {}
                        for (var j = 0; j < taskListModel.count; j++) {
                            var m = taskListModel.get(j)
                            names[m.taskId] = m.taskTitle
                        }
                        var parts = []
                        for (var i = 0; i < ids.length; i++)
                            parts.push((i + 1) + ". " + names[ids[i]] + " (id=" + ids[i] + ")")
                        console.log("[HoverPanel] reorder:\n" + parts.join("\n"))
                        root.service.reorderTasks(ids)
                    }
                    root._dragging = false
                }

                // Let clicks through to FocusHoverTaskItem buttons
                onClicked: function(mouse) { mouse.accepted = false }
            }
        }
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    RowLayout {
        anchors { fill: parent; margins: 14 }
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Header
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Tasks"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
                Image {
                    source: Theme.iconsPath + "arrows-pointing-out.svg"
                    width: 15; height: 15
                    fillMode: Image.PreserveAspectFit
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expand()
                    }
                }
            }

            // List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: todoList
                    anchors.fill: parent
                    clip: true
                    spacing: 2
                    model: visualModel

                    // Smooth animation when items are displaced by a move
                    moveDisplaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Drop zone for the very top (position 0) — no item above to catch it otherwise
                DropArea {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 10
                    onEntered: function(drag) {
                        var from = drag.source ? drag.source.visualIndex : -1
                        if (from <= 0) return
                        root._dragging = true
                        visualModel.items.move(from, 0, 1)
                        var order = root._visualOrder.slice()
                        var moved = order.splice(from, 1)[0]
                        order.splice(0, 0, moved)
                        root._visualOrder = order
                    }
                }
            }
        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: Theme.border
        }

        FocusActivityHeatmap {
            service: root.service
            Layout.alignment: Qt.AlignTop
        }
    }

    // Hover tracking
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: root.panelHoveredChanged(true)
        onExited:  root.panelHoveredChanged(false)
    }
}
