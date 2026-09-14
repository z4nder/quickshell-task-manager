mod commands;

use anyhow::{bail, Result};
use chrono::NaiveDate;
use clap::{Parser, Subcommand};
use focus_db::{Db, ProjectPatch, TaskPatch};

#[derive(Parser)]
#[command(name = "focusctl", about = "Focus Notch CLI", version)]
struct Cli {
    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Show current focus session status
    Status {
        #[arg(long)]
        json: bool,
    },
    /// Start a focus session on a task
    Start {
        task_id: i64,
        #[arg(long)]
        json: bool,
    },
    /// Pause the active session
    Pause {
        #[arg(long)]
        json: bool,
    },
    /// Resume the paused session
    Resume {
        #[arg(long)]
        json: bool,
    },
    /// Stop the active session
    Stop {
        #[arg(long)]
        json: bool,
    },
    /// Task management
    Task {
        #[command(subcommand)]
        action: TaskCmd,
    },
    /// Project management
    Project {
        #[command(subcommand)]
        action: ProjectCmd,
    },
    /// Settings management
    Settings {
        #[command(subcommand)]
        action: SettingsCmd,
    },
}

#[derive(Subcommand)]
enum ProjectCmd {
    /// Add a new project
    Add {
        name: String,
        #[arg(long, default_value = "#e53935")]
        color: String,
        #[arg(long, default_value = "Created")]
        status: String,
        #[arg(long, value_name = "YYYY-MM-DD")]
        start_date: Option<String>,
        #[arg(long, value_name = "YYYY-MM-DD")]
        end_date: Option<String>,
        #[arg(long)]
        estimated_mins: Option<i64>,
        #[arg(long)]
        json: bool,
    },
    /// List all projects
    List {
        #[arg(long)]
        json: bool,
    },
    /// Edit a project
    Edit {
        id: i64,
        #[arg(long)]
        name: Option<String>,
        #[arg(long)]
        color: Option<String>,
        #[arg(long)]
        status: Option<String>,
        #[arg(long, value_name = "YYYY-MM-DD")]
        start_date: Option<String>,
        #[arg(long, value_name = "YYYY-MM-DD")]
        end_date: Option<String>,
        #[arg(long)]
        estimated_mins: Option<i64>,
    },
    /// Delete a project (tasks keep their data, project link is cleared)
    Delete { id: i64 },
}

#[derive(Subcommand)]
enum SettingsCmd {
    /// Get a setting value
    Get { key: String },
    /// Set a setting value
    Set { key: String, value: String },
}

#[derive(Subcommand)]
enum TaskCmd {
    /// Add a new task
    Add {
        title: String,
        /// Schedule date (YYYY-MM-DD)
        #[arg(long, value_name = "YYYY-MM-DD")]
        date: Option<String>,
        /// Estimated focus time in minutes
        #[arg(long, value_name = "MINS")]
        estimated_mins: Option<i64>,
        /// Notes for the task
        #[arg(long)]
        notes: Option<String>,
        /// Associate with a project
        #[arg(long)]
        project_id: Option<i64>,
        #[arg(long)]
        json: bool,
    },
    /// List all tasks
    List {
        #[arg(long)]
        json: bool,
    },
    /// Mark task as done
    Done { id: i64 },
    /// Reopen a completed task
    Undone { id: i64 },
    /// Edit a task's fields (only provided flags are updated)
    Edit {
        id: i64,
        #[arg(long)]
        title: Option<String>,
        /// Set schedule date (YYYY-MM-DD)
        #[arg(long, value_name = "YYYY-MM-DD")]
        date: Option<String>,
        /// Remove schedule date
        #[arg(long)]
        unschedule: bool,
        /// Estimated focus time in minutes (0 = clear)
        #[arg(long, value_name = "MINS")]
        estimated_mins: Option<i64>,
        /// Notes (empty string = clear)
        #[arg(long)]
        notes: Option<String>,
        /// Reset elapsed focus time to zero
        #[arg(long)]
        reset_time: bool,
        /// Set or clear project association (0 = clear)
        #[arg(long)]
        project_id: Option<i64>,
    },
    /// Delete a task
    Delete { id: i64 },
    /// Set the display order of tasks (pass all IDs in desired order)
    Reorder { ids: Vec<i64> },
}

fn parse_date(s: &str) -> Result<NaiveDate> {
    s.parse::<NaiveDate>()
        .map_err(|_| anyhow::anyhow!("Data inválida '{s}', use formato YYYY-MM-DD"))
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let db = Db::open()?;

    match cli.command {
        Cmd::Status { json } => commands::session::status(&db, json),
        Cmd::Start { task_id, json } => commands::session::start(&db, task_id, json),
        Cmd::Pause { json } => commands::session::pause(&db, json),
        Cmd::Resume { json } => commands::session::resume(&db, json),
        Cmd::Stop { json } => commands::session::stop(&db, json),
        Cmd::Task { action } => match action {
            TaskCmd::Add { title, date, estimated_mins, notes, project_id, json } => {
                let parsed_date = date.as_deref().map(parse_date).transpose()?;
                commands::task::add(
                    &db,
                    &title,
                    parsed_date,
                    estimated_mins,
                    notes.as_deref(),
                    project_id,
                    json,
                )
            }
            TaskCmd::List { json } => commands::task::list(&db, json),
            TaskCmd::Done { id } => commands::task::done(&db, id),
            TaskCmd::Undone { id } => commands::task::undone(&db, id),
            TaskCmd::Edit { id, title, date, unschedule, estimated_mins, notes, reset_time, project_id } => {
                if date.is_some() && unschedule {
                    bail!("--date e --unschedule são mutuamente exclusivos");
                }
                if reset_time {
                    db.task_reset_time(id)?;
                }
                let scheduled_date = if unschedule {
                    Some(None)
                } else {
                    date.as_deref().map(parse_date).transpose()?.map(Some)
                };
                let estimated_mins_patch = estimated_mins.map(|m| if m == 0 { None } else { Some(m) });
                let notes_patch = notes.map(|n| if n.is_empty() { None } else { Some(n) });
                let project_id_patch = project_id.map(|p| if p == 0 { None } else { Some(p) });
                commands::task::edit(&db, id, TaskPatch {
                    title,
                    scheduled_date,
                    estimated_mins: estimated_mins_patch,
                    notes: notes_patch,
                    project_id: project_id_patch,
                })
            }
            TaskCmd::Delete { id } => commands::task::delete(&db, id),
            TaskCmd::Reorder { ids } => {
                db.task_reorder(&ids)?;
                Ok(())
            }
        },
        Cmd::Project { action } => match action {
            ProjectCmd::Add { name, color, status, start_date, end_date, estimated_mins, json } => {
                let start = start_date.as_deref().map(parse_date).transpose()?;
                let end = end_date.as_deref().map(parse_date).transpose()?;
                commands::project::add(&db, &name, &color, &status, start, end, estimated_mins, json)
            }
            ProjectCmd::List { json } => commands::project::list(&db, json),
            ProjectCmd::Edit { id, name, color, status, start_date, end_date, estimated_mins } => {
                let start = start_date.as_deref().map(parse_date).transpose()?;
                let end = end_date.as_deref().map(parse_date).transpose()?;
                commands::project::edit(&db, id, ProjectPatch {
                    name, color, status,
                    start_date: start.map(Some),
                    end_date: end.map(Some),
                    estimated_mins: estimated_mins.map(|m| if m == 0 { None } else { Some(m) }),
                })
            }
            ProjectCmd::Delete { id } => commands::project::delete(&db, id),
        },
        Cmd::Settings { action } => match action {
            SettingsCmd::Get { key } => {
                let v = db.setting_get(&key).unwrap_or_default();
                println!("{v}");
                Ok(())
            }
            SettingsCmd::Set { key, value } => {
                db.setting_set(&key, &value)?;
                println!("Setting '{key}' = '{value}'");
                Ok(())
            }
        },
    }
}
