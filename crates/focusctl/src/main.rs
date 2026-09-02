mod commands;

use anyhow::{bail, Result};
use chrono::NaiveDate;
use clap::{Parser, Subcommand};
use focus_db::{Db, TaskPatch};

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
    },
    /// Delete a task
    Delete { id: i64 },
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
            TaskCmd::Add { title, date, estimated_mins, notes, json } => {
                let parsed_date = date.as_deref().map(parse_date).transpose()?;
                commands::task::add(
                    &db,
                    &title,
                    parsed_date,
                    estimated_mins,
                    notes.as_deref(),
                    json,
                )
            }
            TaskCmd::List { json } => commands::task::list(&db, json),
            TaskCmd::Done { id } => commands::task::done(&db, id),
            TaskCmd::Edit { id, title, date, unschedule, estimated_mins, notes } => {
                if date.is_some() && unschedule {
                    bail!("--date e --unschedule são mutuamente exclusivos");
                }
                let scheduled_date = if unschedule {
                    Some(None)
                } else {
                    date.as_deref().map(parse_date).transpose()?.map(Some)
                };
                let estimated_mins_patch = estimated_mins.map(|m| if m == 0 { None } else { Some(m) });
                let notes_patch = notes.map(|n| if n.is_empty() { None } else { Some(n) });
                commands::task::edit(&db, id, TaskPatch {
                    title,
                    scheduled_date,
                    estimated_mins: estimated_mins_patch,
                    notes: notes_patch,
                })
            }
            TaskCmd::Delete { id } => commands::task::delete(&db, id),
        },
    }
}
