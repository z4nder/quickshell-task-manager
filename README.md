# focus-notch

A focus tracker that lives in your Wayland bar. Built with Rust + [Quickshell](https://quickshell.outfoxxed.me/).

Track tasks, projects and focused time without leaving your workflow — click the badge in your bar, pick a task, and go.

---

## Screenshots

| Bar badge | Task list |
|-----------|-----------|
| ![Bar badge](assets/pints/nav_bar.png) | ![Tasks](assets/pints/tasks.png) |

| Projects | Statistics |
|----------|------------|
| ![Projects](assets/pints/projects.png) | ![Report](assets/pints/report.png) |

![Settings](assets/pints/settings.png)

---

## Features

- **Bar badge** — always-visible pill showing active task, elapsed time and a progress trail. Click to play/pause.
- **Hover panel** — hover the badge to see today's tasks without opening the full window.
- **Task manager** — add, edit, complete and delete tasks. Schedule by date or leave unscheduled.
- **Projects** — group tasks into color-coded projects with status, description and date range.
- **Statistics** — time spent per project or per task, completion progress and recent activity. Filter by this month, 3 months, 6 months or year.
- **Activity heatmap** — GitHub-style calendar showing focus history.
- **Themes** — 9 built-in themes (Dark, Nord, Dracula, Tokyo Night, Catppuccin Mocha, Gruvbox, Evangelion Unit-01/02, Light). Swap at runtime from settings.

---

## Requirements

- Linux with a Wayland compositor (Hyprland, Sway, etc.)
- [Quickshell](https://quickshell.outfoxxed.me/) — Qt-based shell toolkit
- Rust + Cargo (for building from source)

---

## Installation

### Option A — Generic Linux (any distro)

```bash
git clone https://github.com/your-user/focus-notch
cd focus-notch
./install.sh
```

This will:
1. Build `focusctl` with `cargo build --release`
2. Install the binary to `~/.local/bin/focusctl`
3. Deploy QML components and icons to `~/.config/quickshell/`

Make sure `~/.local/bin` is in your `$PATH`.

Then add the widget to your Quickshell bar config:

```qml
// In your bar's QML file
FocusWidget {
    barWindow: root
}
```

### Option B — NixOS / home-manager (flake)

Add the flake input:

```nix
# flake.nix
inputs.focus-notch.url = "github:your-user/focus-notch";
```

Then enable the module:

```nix
# home.nix or equivalent
{ inputs, ... }: {
  imports = [ inputs.focus-notch.homeManagerModules.default ];

  programs.focus-notch.enable = true;
}
```

The module handles the binary, QML files and icons automatically.

---

## Usage

Once installed, the widget appears in your bar. Basic workflow:

1. **Open** the full window by clicking the expand icon on the hover panel.
2. **Add a task** — type in the "Nova tarefa..." field and press Enter. Optionally set estimated minutes and assign a project.
3. **Start a session** — click the play button on any task. The bar badge starts counting.
4. **Pause / resume** — click the badge in the bar, or use the play/pause button in the task list.
5. **Done** — click the circle checkbox on the task. It fades out after 1 second (click again to cancel).

### CLI

All state is managed by `focusctl`. You can drive it directly:

```bash
# Tasks
focusctl task add "Write tests" --estimated-mins 45
focusctl task list --json
focusctl task done 3
focusctl task edit 3 --title "Write unit tests" --project-id 1

# Sessions
focusctl start 3
focusctl pause
focusctl resume
focusctl stop

# Projects
focusctl project add "Backend" --color "#4488ff" --status InProgress
focusctl project list --json
focusctl project edit 1 --status Completed

# Settings
focusctl settings set theme dracula
focusctl settings set roll_incomplete true
```

---

## Data

Tasks, projects, sessions and settings are stored in a single SQLite database at:

```
~/.local/share/focus/focus.db
```

No cloud, no accounts, no sync — your data stays local.

---

## Development

```bash
# Enter dev shell (Nix)
nix develop

# Build CLI
cargo build -p focusctl

# Run UI with live log tailing
./debugger.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development guide — project structure, architecture overview, how to add views/commands, database inspection, log locations and QML gotchas.

---

## License

MIT
