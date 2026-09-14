import QtQuick
import Quickshell.Io

// Central state manager. Instantiate once in shell.qml.
Item {
    id: root
    visible: false; width: 0; height: 0

    // ── Config ────────────────────────────────────────────────────────────
    property string focusBin: "focusctl"

    // ── Exposed state ─────────────────────────────────────────────────────
    property bool   sessionActive: false
    property bool   sessionPaused: false
    property int    elapsedSecs:   0
    property var    currentTask:   null   // task object or null
    property var    tasks:         []     // all tasks array

    // Progress 0.0–1.0 for the border trail
    readonly property real progress: {
        if (!sessionActive || !currentTask) return 0
        var est = currentTask.estimated_mins
        if (!est || est <= 0) return 0
        return Math.min(1.0, elapsedSecs / (est * 60))
    }

    // ── Status polling ────────────────────────────────────────────────────
    property string _statusBuf: ""

    Process {
        id: statusProc
        command: [root.focusBin, "status", "--json"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._statusBuf += line }
        }

        onExited: function(code) {
            if (code === 0 && root._statusBuf !== "") {
                try {
                    var s = JSON.parse(root._statusBuf)
                    root.sessionActive = s.active  || false
                    root.sessionPaused = s.paused  || false
                    root.elapsedSecs   = s.elapsed_secs || 0
                    root.currentTask   = s.task    || null
                } catch(e) { console.warn("status parse:", e) }
            }
            root._statusBuf = ""
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { if (!statusProc.running) statusProc.running = true }
    }

    // ── Task list ─────────────────────────────────────────────────────────
    property string _tasksBuf: ""

    Process {
        id: tasksProc
        command: [root.focusBin, "task", "list", "--json"]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._tasksBuf += line }
        }

        onExited: function(code) {
            if (code === 0 && root._tasksBuf !== "") {
                try {
                    var parsed = JSON.parse(root._tasksBuf)
                    var order = parsed.map(function(t) { return t.id + ":" + t.title }).join(", ")
                    console.log("[FocusService] tasks loaded:", order)
                    root.tasks = parsed
                } catch(e) { console.warn("[FocusService] tasks parse error:", e) }
            }
            root._tasksBuf = ""
        }
    }

    function refreshTasks() {
        if (!tasksProc.running) {
            console.log("[FocusService] refreshTasks()")
            tasksProc.running = true
        } else {
            console.warn("[FocusService] refreshTasks() skipped — tasksProc already running")
        }
    }

    // ── Action process (sequential, one at a time) ────────────────────────
    property var    _actionQueue:    []
    property bool   _actionRunning:  false

    property string _actionStderr: ""

    Process {
        id: actionProc
        running: false

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (line !== "") root._actionStderr += line + "\n"
            }
        }

        onExited: function(code) {
            var cmd = actionProc.command.join(" ")
            if (code !== 0) {
                console.warn("[FocusService] command failed (exit " + code + "):", cmd)
                if (root._actionStderr !== "")
                    console.warn("[FocusService] stderr:", root._actionStderr.trim())
            } else {
                console.log("[FocusService] ok:", cmd)
            }
            root._actionStderr = ""
            root._actionRunning = false
            root._drainQueue()
        }
    }

    function _drainQueue() {
        if (_actionRunning || _actionQueue.length === 0) return
        var item = _actionQueue.shift()
        _actionRunning = true
        actionProc.command = item.cmd
        console.log("[FocusService] run:", item.cmd.join(" "))
        actionProc.running = true
        if (item.refresh) {
            actionProc.onExited.connect(function refresh() {
                root.refreshTasks()
                actionProc.onExited.disconnect(refresh)
            })
        }
    }

    function _enqueue(cmd, refresh) {
        console.log("[FocusService] enqueue:", cmd.join(" "))
        _actionQueue.push({ cmd: cmd, refresh: refresh || false })
        _drainQueue()
    }

    // ── Public action API ─────────────────────────────────────────────────
    function startSession(taskId) {
        _enqueue([focusBin, "start", String(taskId)], false)
    }
    function pauseSession()  { _enqueue([focusBin, "pause"],  false) }
    function resumeSession() { _enqueue([focusBin, "resume"], false) }
    function stopSession()   { _enqueue([focusBin, "stop"],   false) }

    function addTask(title, scheduledDate) {
        var cmd = [focusBin, "task", "add", title]
        if (scheduledDate && scheduledDate !== "") {
            cmd.push("--date")
            cmd.push(scheduledDate)
        }
        _enqueue(cmd, true)
    }

    function doneTask(id)      { _enqueue([focusBin, "task", "done",   String(id)], true) }
    function undoneTask(id)    { _enqueue([focusBin, "task", "undone", String(id)], true) }
    function deleteTask(id)    { _enqueue([focusBin, "task", "delete", String(id)], true) }
    function resetTaskTime(id) { _enqueue([focusBin, "task", "edit", String(id), "--reset-time"], true) }

    function reorderTasks(ids) {
        var cmd = [focusBin, "task", "reorder"]
        for (var i = 0; i < ids.length; i++) cmd.push(String(ids[i]))
        _enqueue(cmd, true)
    }

    function editTask(id, title, date, estimatedMins, notes) {
        var cmd = [focusBin, "task", "edit", String(id)]
        if (title        && title !== "")         { cmd.push("--title");         cmd.push(title) }
        if (date         && date  !== "")         { cmd.push("--date");          cmd.push(date)  }
        else if (date    === "")                   { cmd.push("--unschedule") }
        if (estimatedMins >= 0)                   { cmd.push("--estimated-mins"); cmd.push(String(estimatedMins)) }
        if (notes        !== null && notes !== undefined) { cmd.push("--notes"); cmd.push(notes) }
        _enqueue(cmd, true)
    }

    // ── Helpers (used by QML components) ──────────────────────────────────

    // Format seconds → MM:SS
    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    // Sort helper: incomplete tasks first, completed at bottom
    function _sortedByCompletion(arr) {
        return arr.slice().sort(function(a, b) {
            return (a.completed ? 1 : 0) - (b.completed ? 1 : 0)
        })
    }

    // Return tasks scheduled for a given Date object (order from DB sort_order)
    function tasksForDate(date) {
        var iso = Qt.formatDate(date, "yyyy-MM-dd")
        return tasks.filter(function(t) { return t.scheduled_date === iso })
    }

    // Count completed tasks scheduled for a given date.
    function completedCountForDate(date) {
        var iso = Qt.formatDate(date, "yyyy-MM-dd")
        return tasks.filter(function(t) {
            return t.completed && t.scheduled_date === iso
        }).length
    }

    // Return unscheduled tasks (order from DB sort_order)
    function unscheduledTasks() {
        return tasks.filter(function(t) { return !t.scheduled_date })
    }

    Component.onCompleted: {
        statusProc.running = true
        refreshTasks()
    }
}
