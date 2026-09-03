use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: i64,
    pub title: String,
    pub completed: bool,
    pub created_at: DateTime<Utc>,
    pub completed_at: Option<DateTime<Utc>>,
    pub scheduled_date: Option<NaiveDate>,
    pub estimated_mins: Option<i64>,
    pub notes: Option<String>,
    /// Last time a focus session was started on this task
    pub latest_focus_at: Option<DateTime<Utc>>,
    /// Last time a focus session was paused on this task
    pub latest_pause_at: Option<DateTime<Utc>>,
    /// Total focused seconds accumulated across all completed sessions
    pub elapsed_secs: u64,
}

impl fmt::Display for Task {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let status = if self.completed { "✓" } else { "○" };
        write!(f, "[{}] #{} {}", status, self.id, self.title)?;
        if let Some(d) = self.scheduled_date {
            write!(f, "  📅 {d}")?;
        }
        if let Some(m) = self.estimated_mins {
            write!(f, "  ⏱ {m}min")?;
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FocusSession {
    pub id: i64,
    pub task_id: Option<i64>,
    pub started_at: DateTime<Utc>,
    pub ended_at: Option<DateTime<Utc>>,
    pub paused_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatusOutput {
    pub active: bool,
    pub paused: bool,
    pub session: Option<FocusSession>,
    pub task: Option<Task>,
    pub elapsed_secs: u64,
}

impl fmt::Display for StatusOutput {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.session {
            None => write!(f, "Nenhuma sessão ativa"),
            Some(_) => {
                let mins = self.elapsed_secs / 60;
                let secs = self.elapsed_secs % 60;
                let task_title = self
                    .task
                    .as_ref()
                    .map(|t| t.title.as_str())
                    .unwrap_or("(sem tarefa)");
                let state = if self.paused { " [pausado]" } else { "" };
                write!(f, "● {}{}  {:02}:{:02}", task_title, state, mins, secs)
            }
        }
    }
}
