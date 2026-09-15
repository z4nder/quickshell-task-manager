import QtQuick
import Quickshell.Io as Io

// Central state manager. Instantiate once in shell.qml.
Item {
    id: root
    visible: false; width: 0; height: 0

    // ── Config ────────────────────────────────────────────────────────────
    property string focusBin: "focusctl"

    // ── Exposed state ─────────────────────────────────────────────────────
    property bool   sessionActive:       false
    property bool   sessionPaused:       false
    property int    elapsedSecs:         0
    property var    currentTask:         null   // task object or null
    property var    tasks:               []     // all tasks array
    property var    projects:            []     // all projects array
    property bool   rollIncomplete:      false  // setting: roll over incomplete tasks
    property string currentTheme:        "default-dark" // active theme name

    // Themes loaded from themes.json at startup
    property var themes: ({})

    // Reactive: re-evaluates when themes loads or currentTheme changes
    readonly property var themeData: {
        if (themes && themes[currentTheme]) return themes[currentTheme]
        if (themes && themes["default-dark"]) return themes["default-dark"]
        // Minimal built-in fallback — only used before themes.json loads
        return { bg: "#18181B", bgPanel: "#202024", bgItem: "#2A2A2F", bgHover: "#35353B",
                 textPrimary: "#F4F4F5", textSecondary: "#A1A1AA", textMuted: "#71717A",
                 accent: "#EF4444", accentAlt: "#22C55E", accentDim: "#7F1D1D",
                 danger: "#EF4444", warning: "#F59E0B", border: "#3F3F46" }
    }

    // Ordered list of theme keys (for the picker)
    readonly property var themeKeys: themes ? Object.keys(themes) : []

    // Progress 0.0–1.0 for the border trail
    readonly property real progress: {
        if (!sessionActive || !currentTask) return 0
        var est = currentTask.estimated_mins
        if (!est || est <= 0) return 0
        return Math.min(1.0, elapsedSecs / (est * 60))
    }

    // ── Status polling ────────────────────────────────────────────────────
    property string _statusBuf: ""

    Io.Process {
        id: statusProc
        command: [root.focusBin, "status", "--json"]
        running: false

        stdout: Io.SplitParser {
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

    Io.Process {
        id: tasksProc
        command: [root.focusBin, "task", "list", "--json"]
        running: false

        stdout: Io.SplitParser {
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

    // ── Project list ──────────────────────────────────────────────────────
    property string _projectsBuf: ""

    Io.Process {
        id: projectsProc
        command: [root.focusBin, "project", "list", "--json"]
        running: false

        stdout: Io.SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._projectsBuf += line }
        }

        onExited: function(code) {
            if (code === 0 && root._projectsBuf !== "") {
                try {
                    var parsed = JSON.parse(root._projectsBuf)
                    root.projects = parsed
                } catch(e) { console.warn("[FocusService] projects parse error:", e) }
            } else if (code === 0 && root._projectsBuf === "") {
                root.projects = []
            }
            root._projectsBuf = ""
        }
    }

    function refreshProjects() {
        if (!projectsProc.running) {
            console.log("[FocusService] refreshProjects()")
            projectsProc.running = true
        } else {
            console.warn("[FocusService] refreshProjects() skipped — projectsProc already running")
        }
    }

    // ── Action process (sequential, one at a time) ────────────────────────
    property var    _actionQueue:    []
    property bool   _actionRunning:  false

    property string _actionStderr: ""

    Io.Process {
        id: actionProc
        running: false

        stderr: Io.SplitParser {
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
        if (item.refreshProj) {
            actionProc.onExited.connect(function refreshP() {
                root.refreshProjects()
                actionProc.onExited.disconnect(refreshP)
            })
        }
    }

    function _enqueue(cmd, refresh, refreshProj) {
        console.log("[FocusService] enqueue:", cmd.join(" "))
        _actionQueue.push({ cmd: cmd, refresh: refresh || false, refreshProj: refreshProj || false })
        _drainQueue()
    }

    // ── Public action API ─────────────────────────────────────────────────
    function startSession(taskId) {
        _enqueue([focusBin, "start", String(taskId)], false)
    }
    function pauseSession()  { _enqueue([focusBin, "pause"],  false) }
    function resumeSession() { _enqueue([focusBin, "resume"], false) }
    function stopSession()   { _enqueue([focusBin, "stop"],   false) }

    function addTask(title, scheduledDate, estimatedMins, projectId) {
        var cmd = [focusBin, "task", "add", title]
        if (scheduledDate && scheduledDate !== "") {
            cmd.push("--date")
            cmd.push(scheduledDate)
        }
        if (estimatedMins && estimatedMins > 0) {
            cmd.push("--estimated-mins")
            cmd.push(String(estimatedMins))
        }
        if (projectId) {
            cmd.push("--project-id")
            cmd.push(String(projectId))
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

    function editTaskDate(id, date) {
        var cmd = [focusBin, "task", "edit", String(id)]
        if (date) { cmd.push("--date"); cmd.push(date) }
        else { cmd.push("--unschedule") }
        _enqueue(cmd, true)
    }

    function setRollIncomplete(enabled) {
        root.rollIncomplete = enabled
        _enqueue([focusBin, "settings", "set", "roll_incomplete", enabled ? "true" : "false"], false)
    }

    // ── Project action API ────────────────────────────────────────────────
    function addProject(name, color, status, startDate, endDate, estimatedMins) {
        var cmd = [focusBin, "project", "add", name,
                   "--color", color, "--status", status]
        if (startDate)    { cmd.push("--start-date"); cmd.push(startDate) }
        if (endDate)      { cmd.push("--end-date");   cmd.push(endDate) }
        if (estimatedMins && estimatedMins > 0) {
            cmd.push("--estimated-mins"); cmd.push(String(estimatedMins))
        }
        _enqueue(cmd, false, true)
    }

    function editProject(id, name, color, status, startDate, endDate, estimatedMins) {
        var cmd = [focusBin, "project", "edit", String(id)]
        if (name)   { cmd.push("--name");   cmd.push(name) }
        if (color)  { cmd.push("--color");  cmd.push(color) }
        if (status) { cmd.push("--status"); cmd.push(status) }
        if (startDate) { cmd.push("--start-date"); cmd.push(startDate) }
        if (endDate)   { cmd.push("--end-date");   cmd.push(endDate) }
        if (estimatedMins !== null && estimatedMins !== undefined) {
            cmd.push("--estimated-mins"); cmd.push(String(estimatedMins))
        }
        _enqueue(cmd, false, true)
    }

    function deleteProject(id) {
        _enqueue([focusBin, "project", "delete", String(id)], true, true)
    }

    function editTaskProject(taskId, projectId) {
        var pid = projectId ? String(projectId) : "0"
        _enqueue([focusBin, "task", "edit", String(taskId), "--project-id", pid], true)
    }

    function persistTheme(name) {
        _enqueue([focusBin, "settings", "set", "theme", name], false)
    }

    // ── Load settings on startup ──────────────────────────────────────────
    property string _settingBuf: ""
    Io.Process {
        id: settingProc
        command: [root.focusBin, "settings", "get", "roll_incomplete"]
        running: false
        stdout: Io.SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._settingBuf += line }
        }
        onExited: function() {
            root.rollIncomplete = root._settingBuf.trim() === "true"
            root._settingBuf = ""
            themeProcLoad.running = true
        }
    }

    property string _themeBuf: ""
    Io.Process {
        id: themeProcLoad
        command: [root.focusBin, "settings", "get", "theme"]
        running: false
        stdout: Io.SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._themeBuf += line }
        }
        onExited: function() {
            var t = root._themeBuf.trim()
            if (t !== "") root.currentTheme = t
            root._themeBuf = ""
        }
    }

    // ── Load themes.json ──────────────────────────────────────────────────
    property string _themesBuf: ""
    Io.Process {
        id: themesJsonProc
        // Qt.resolvedUrl gives us the absolute path of themes.json next to this QML file
        command: ["cat", Qt.resolvedUrl("themes.json").toString().replace("file://", "")]
        running: false
        stdout: Io.SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._themesBuf += line }
        }
        onExited: function(code) {
            if (code === 0 && root._themesBuf !== "") {
                try {
                    root.themes = JSON.parse(root._themesBuf)
                    console.log("[FocusService] themes.json loaded:", Object.keys(root.themes).join(", "))
                } catch(e) {
                    console.warn("[FocusService] themes.json parse error:", e)
                }
            }
            root._themesBuf = ""
        }
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

    // Find project color for a given project_id
    function projectColor(projectId) {
        if (!projectId || !projects) return ""
        for (var i = 0; i < projects.length; i++) {
            if (projects[i].id === projectId) return projects[i].color
        }
        return ""
    }

    // Find project name for a given project_id
    function projectName(projectId) {
        if (!projectId || !projects) return ""
        for (var i = 0; i < projects.length; i++) {
            if (projects[i].id === projectId) return projects[i].name
        }
        return ""
    }

    Component.onCompleted: {
        themesJsonProc.running = true
        settingProc.running = true
        statusProc.running = true
        refreshTasks()
        refreshProjects()
    }
}
