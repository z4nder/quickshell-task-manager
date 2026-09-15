# Contributing & Development Guide

## Project structure

```
focus-notch/
├── crates/
│   ├── focus-core/      # Data models (Task, Project, FocusSession, ...)
│   ├── focus-db/        # SQLite layer — all DB operations live here
│   └── focusctl/        # CLI binary (clap) — thin wrapper over focus-db
├── quickshell/
│   ├── shell.qml        # Entrypoint for the legacy component layout
│   └── config/          # All active QML/JS components (Focus* prefix)
│       ├── FocusService.qml        # Central state — polls focusctl, exposes reactive properties
│       ├── FocusWidget.qml         # Root widget mounted in the bar
│       ├── FocusBarBadge.qml       # Pill badge (timer + progress trail canvas)
│       ├── FocusHoverPanel.qml     # Hover popup over the badge
│       ├── FocusAppScreen.qml      # Full window (Tasks / Projects / Stats)
│       ├── FocusProjectsView.qml   # Projects grid view
│       ├── FocusStatsView.qml      # Statistics view
│       ├── FocusMonthCalendar.qml  # Mini calendar component
│       ├── FocusDatePicker.qml     # Date field with calendar popup
│       ├── FocusActivityHeatmap.qml
│       ├── FocusFullTaskItem.qml   # Task row in the full screen
│       ├── FocusHoverTaskItem.qml  # Task row in the hover panel
│       ├── FocusTheme.js           # Static fallback theme values
│       └── themes.json             # Runtime theme presets (loaded by FocusService)
├── nix/
│   ├── hm-module.nix    # Home-manager module
│   └── package.nix      # Nix package derivation for focusctl
├── assets/              # Raw SVG icons (Heroicons)
├── docs/                # Internal planning docs
├── debugger.sh          # Dev runner with live log tailing
├── install.sh           # Generic Linux installer
└── flake.nix
```

---

## Setup

### With Nix (recommended)

```bash
git clone https://github.com/your-user/focus-notch
cd focus-notch
nix develop          # drops into a shell with Rust + quickshell + tools
```

### Without Nix

You need:
- Rust stable (via [rustup](https://rustup.rs/))
- [Quickshell](https://quickshell.outfoxxed.me/) installed and in `PATH`

```bash
git clone https://github.com/your-user/focus-notch
cd focus-notch
cargo build -p focusctl
```

---

## Running during development

### Backend (CLI)

```bash
# Build and run focusctl directly
cargo run -p focusctl -- task list --json
cargo run -p focusctl -- task add "Test task" --estimated-mins 30
cargo run -p focusctl -- start 1
cargo run -p focusctl -- status --json

# Watch for changes and rebuild
cargo watch -x "build -p focusctl"
```

### UI (Quickshell)

Use the `debugger.sh` script — it kills any running instance, rotates the log file, starts Quickshell and tails the output to both the terminal and `logs/debug.log`:

```bash
./debugger.sh
```

By default it loads the config from your nixos-setup path. To point it at the repo config directly:

```bash
./debugger.sh ./quickshell/config
```

The log file is at `logs/debug.log` and keeps the last 500 lines on each run. Useful for catching QML errors that scroll off the terminal.

**Common Quickshell errors:**

| Error | Cause |
|-------|-------|
| `id is not unique` | Two QML items share the same `id:` within scope |
| `Cannot assign to non-existent property "on_xyzChanged"` | QML signal handlers can't start with underscore — rename the property or use a `Connections {}` block with `function onXyzChanged()` |
| `Type FooBar unavailable` | A component file is missing or has a parse error preventing it from loading |
| `Cannot read property of null` | A property is accessed before `service` is set — guard with `service && service.foo` |

---

## Architecture overview

### Data flow

```
focusctl (CLI) ──► focus-db (SQLite) ──► ~/.local/share/focus/focus.db
      ▲
      │  Io.Process (QML)
      │
FocusService.qml
  - polls `focusctl status --json` every 1s  → sessionActive, elapsedSecs, currentTask
  - polls `focusctl task list --json`         → tasks[]
  - polls `focusctl project list --json`      → projects[]
  - exposes reactive properties to all views
```

All UI state lives in `FocusService`. Components never call `focusctl` directly — they call methods on `service` (e.g. `service.addTask(...)`, `service.startSession(id)`).

### Theme system

Themes are defined in `themes.json` and loaded at runtime by `FocusService` using `Io.Process` (`cat themes.json`). The active theme is stored as `service.currentTheme` (a string key). All components read colors from `_theme`, a local alias:

```qml
readonly property var _theme: (service && service.themeData) ? service.themeData : {
    // static fallback from FocusTheme.js
    accent: Theme.accent, bg: Theme.bg, ...
}
```

To add a new theme: add an entry to `themes.json` with the 13 required color tokens:
`bg, bgPanel, bgItem, bgHover, textPrimary, textSecondary, textMuted, accent, accentAlt, accentDim, danger, warning, border`

### Adding a new view

1. Create `FocusYourView.qml` in `quickshell/config/`
2. Add a nav entry in `FocusAppScreen.qml`:
   ```qml
   model: [
       { label: "Tarefas",  idx: 0 },
       { label: "Projetos", idx: 1 },
       { label: "Stats",    idx: 2 },
       { label: "YourView", idx: 3 },  // ← add here
   ]
   ```
3. Mount the view in the content area:
   ```qml
   FocusYourView {
       anchors { fill: parent; margins: 14 }
       visible: root._view === 3
       service: root.service
   }
   ```
4. Copy to nixos-setup if you're running from there:
   ```bash
   cp quickshell/config/FocusYourView.qml \
      ~/projects/nixos/nixos-setup/modules/hyprland/quickshell/config/
   ```

### Adding a new CLI command

1. Add the subcommand to the `enum` in `crates/focusctl/src/main.rs`
2. Implement DB operations in `crates/focus-db/src/lib.rs`
3. Add the model/struct if needed in `crates/focus-core/src/models.rs`
4. Expose via `FocusService.qml` with a new function that calls `_enqueue([focusBin, ...])`

---

## Syncing both config copies

The active config lives in two places:
- `quickshell/config/` — repo source
- `~/projects/nixos/nixos-setup/modules/hyprland/quickshell/config/` — what `debugger.sh` loads by default

After editing a file, sync it:

```bash
cp quickshell/config/FocusFoo.qml \
   ~/projects/nixos/nixos-setup/modules/hyprland/quickshell/config/FocusFoo.qml
```

Or sync everything at once:

```bash
cp quickshell/config/Focus*.qml \
   quickshell/config/FocusTheme.js \
   quickshell/config/themes.json \
   ~/projects/nixos/nixos-setup/modules/hyprland/quickshell/config/
```

---

## Database

The SQLite database is at `~/.local/share/focus/focus.db`. You can inspect it directly:

```bash
sqlite3 ~/.local/share/focus/focus.db

# Useful queries
.tables
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 10;
SELECT * FROM projects;
SELECT * FROM focus_sessions ORDER BY started_at DESC LIMIT 20;
SELECT id, title, elapsed_secs FROM tasks WHERE elapsed_secs > 0;
```

To reset everything:

```bash
rm ~/.local/share/focus/focus.db
# focusctl will recreate the schema on next run
```

---

## Logs

Quickshell logs go to `/run/user/1000/quickshell/by-id/<id>/log.qslog`.

The `debugger.sh` script also writes to `logs/debug.log` in the repo root and keeps the last 500 lines across restarts.

```bash
# Live tail without the debugger script
tail -f /run/user/1000/quickshell/by-id/*/log.qslog

# Search for QML errors
grep -i "error\|warn\|undefined" logs/debug.log
```

---

## Code style

- Rust: `cargo fmt` + `cargo clippy` before committing
- QML: no hard rules, but follow the existing pattern — `readonly property` for derived state, `_camelCase` for internal properties, no `on_underscoreChanged` handlers (QML doesn't support them)
- Keep both config copies in sync (repo + nixos-setup)
