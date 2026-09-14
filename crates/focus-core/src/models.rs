use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;

// ── DateTime serde helpers (millisecond precision for JS compatibility) ───────
//
// chrono's default serializer uses nanoseconds ("...123456789Z") which
// JavaScript's Date constructor cannot parse. These modules cap at 3 decimals.

mod dt_ms {
    use chrono::{DateTime, Utc};
    use serde::{Deserializer, Serializer, de::Error};

    pub fn serialize<S: Serializer>(dt: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&dt.format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<DateTime<Utc>, D::Error> {
        let s: String = serde::Deserialize::deserialize(d)?;
        s.parse::<DateTime<Utc>>().map_err(D::Error::custom)
    }
}

mod dt_ms_opt {
    use chrono::{DateTime, Utc};
    use serde::{Deserializer, Serializer, de::Error};

    pub fn serialize<S: Serializer>(dt: &Option<DateTime<Utc>>, s: S) -> Result<S::Ok, S::Error> {
        match dt {
            Some(dt) => s.serialize_some(&dt.format("%Y-%m-%dT%H:%M:%S%.3fZ").to_string()),
            None => s.serialize_none(),
        }
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Option<DateTime<Utc>>, D::Error> {
        let s: Option<String> = serde::Deserialize::deserialize(d)?;
        match s {
            Some(s) => s.parse::<DateTime<Utc>>().map(Some).map_err(D::Error::custom),
            None => Ok(None),
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: i64,
    pub title: String,
    pub completed: bool,
    #[serde(with = "dt_ms")]
    pub created_at: DateTime<Utc>,
    #[serde(with = "dt_ms_opt")]
    pub completed_at: Option<DateTime<Utc>>,
    pub scheduled_date: Option<NaiveDate>,
    pub estimated_mins: Option<i64>,
    pub notes: Option<String>,
    #[serde(with = "dt_ms_opt")]
    pub latest_focus_at: Option<DateTime<Utc>>,
    #[serde(with = "dt_ms_opt")]
    pub latest_pause_at: Option<DateTime<Utc>>,
    pub elapsed_secs: u64,
    pub project_id: Option<i64>,
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
pub struct Project {
    pub id: i64,
    pub name: String,
    pub color: String,
    pub status: String,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub estimated_mins: Option<i64>,
    #[serde(with = "dt_ms")]
    pub created_at: DateTime<Utc>,
}

impl fmt::Display for Project {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] #{} {} ({})", self.color, self.id, self.name, self.status)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FocusSession {
    pub id: i64,
    pub task_id: Option<i64>,
    #[serde(with = "dt_ms")]
    pub started_at: DateTime<Utc>,
    #[serde(with = "dt_ms_opt")]
    pub ended_at: Option<DateTime<Utc>>,
    #[serde(with = "dt_ms_opt")]
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
