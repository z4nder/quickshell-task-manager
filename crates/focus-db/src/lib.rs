use chrono::{DateTime, NaiveDate, Utc};
use directories::ProjectDirs;
use focus_core::{
    models::{FocusSession, Project, StatusOutput, Task},
    session,
};
use rusqlite::{Connection, Result as SqlResult, params};
use std::path::PathBuf;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DbError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),
    #[error("No active session")]
    NoActiveSession,
    #[error("Session already paused")]
    AlreadyPaused,
    #[error("Session is not paused")]
    NotPaused,
    #[error("Task not found: {0}")]
    TaskNotFound(i64),
    #[error("Cannot find data directory")]
    NoDataDir,
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// Partial update for a task — None means "don't change this field".
/// For nullable fields, Some(None) means "clear the value".
pub struct TaskPatch {
    pub title: Option<String>,
    pub scheduled_date: Option<Option<NaiveDate>>,
    pub estimated_mins: Option<Option<i64>>,
    pub notes: Option<Option<String>>,
    pub project_id: Option<Option<i64>>,
}

pub struct ProjectPatch {
    pub name: Option<String>,
    pub color: Option<String>,
    pub status: Option<String>,
    pub start_date: Option<Option<NaiveDate>>,
    pub end_date: Option<Option<NaiveDate>>,
    pub estimated_mins: Option<Option<i64>>,
}

pub struct Db {
    conn: Connection,
}

impl Db {
    pub fn open() -> Result<Self, DbError> {
        let path = Self::db_path()?;
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(&path)?;
        let db = Db { conn };
        db.migrate()?;
        let _ = db.apply_rollover();
        Ok(db)
    }

    pub fn open_in_memory() -> Result<Self, DbError> {
        let conn = Connection::open_in_memory()?;
        let db = Db { conn };
        db.migrate()?;
        Ok(db)
    }

    fn db_path() -> Result<PathBuf, DbError> {
        ProjectDirs::from("dev", "focus-notch", "focus-notch")
            .map(|d| d.data_dir().join("focus.db"))
            .ok_or(DbError::NoDataDir)
    }

    fn migrate(&self) -> SqlResult<()> {
        self.conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS tasks (
                id               INTEGER PRIMARY KEY,
                title            TEXT NOT NULL,
                completed        INTEGER NOT NULL DEFAULT 0,
                created_at       TEXT NOT NULL,
                completed_at     TEXT,
                scheduled_date   TEXT,
                estimated_mins   INTEGER,
                notes            TEXT,
                latest_focus_at  TEXT,
                latest_pause_at  TEXT,
                elapsed_secs     INTEGER NOT NULL DEFAULT 0,
                sort_order       INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS focus_sessions (
                id          INTEGER PRIMARY KEY,
                task_id     INTEGER,
                started_at  TEXT NOT NULL,
                ended_at    TEXT,
                paused_at   TEXT,
                FOREIGN KEY(task_id) REFERENCES tasks(id)
            );
            ",
        )?;
        // Add columns to existing DBs (silently ignored if already present)
        let _ = self.conn.execute(
            "ALTER TABLE tasks ADD COLUMN elapsed_secs INTEGER NOT NULL DEFAULT 0",
            [],
        );
        let _ = self.conn.execute(
            "ALTER TABLE tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0",
            [],
        );
        let _ = self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS settings (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );",
        );
        let _ = self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS projects (
                id             INTEGER PRIMARY KEY,
                name           TEXT NOT NULL,
                color          TEXT NOT NULL DEFAULT '#e53935',
                status         TEXT NOT NULL DEFAULT 'Created',
                start_date     TEXT,
                end_date       TEXT,
                estimated_mins INTEGER,
                created_at     TEXT NOT NULL
            );",
        );
        let _ = self.conn.execute(
            "ALTER TABLE tasks ADD COLUMN project_id INTEGER REFERENCES projects(id)",
            [],
        );
        Ok(())
    }

    // ── Settings ──────────────────────────────────────────────────────────

    pub fn setting_get(&self, key: &str) -> Option<String> {
        self.conn.query_row(
            "SELECT value FROM settings WHERE key = ?1",
            params![key],
            |row| row.get(0),
        ).ok()
    }

    pub fn setting_set(&self, key: &str, value: &str) -> SqlResult<()> {
        self.conn.execute(
            "INSERT INTO settings (key, value) VALUES (?1, ?2)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            params![key, value],
        )?;
        Ok(())
    }

    /// If roll_incomplete is enabled, reschedule past incomplete tasks to today.
    pub fn apply_rollover(&self) -> SqlResult<()> {
        let enabled = self.setting_get("roll_incomplete")
            .map(|v| v == "true")
            .unwrap_or(false);
        if !enabled {
            return Ok(());
        }
        let today = Utc::now().format("%Y-%m-%d").to_string();
        self.conn.execute(
            "UPDATE tasks SET scheduled_date = ?1
             WHERE completed = 0
               AND scheduled_date IS NOT NULL
               AND scheduled_date < ?1",
            params![today],
        )?;
        Ok(())
    }

    // ── Tasks ─────────────────────────────────────────────────────────────

    pub fn task_add(
        &self,
        title: &str,
        scheduled_date: Option<NaiveDate>,
        estimated_mins: Option<i64>,
        notes: Option<&str>,
    ) -> Result<Task, DbError> {
        let now = Utc::now();
        let date_s = scheduled_date.map(|d| d.to_string());
        let next_order: i64 = self.conn.query_row(
            "SELECT COALESCE(MIN(sort_order), 1) - 1 FROM tasks",
            [],
            |row| row.get(0),
        ).unwrap_or(0);
        self.conn.execute(
            "INSERT INTO tasks (title, completed, created_at, scheduled_date, estimated_mins, notes, sort_order)
             VALUES (?1, 0, ?2, ?3, ?4, ?5, ?6)",
            params![title, now.to_rfc3339(), date_s, estimated_mins, notes, next_order],
        )?;
        let id = self.conn.last_insert_rowid();
        Ok(Task {
            id,
            title: title.to_string(),
            completed: false,
            created_at: now,
            completed_at: None,
            scheduled_date,
            estimated_mins,
            notes: notes.map(str::to_string),
            latest_focus_at: None,
            latest_pause_at: None,
            elapsed_secs: 0,
            project_id: None,
        })
    }

    pub fn task_list(&self) -> Result<Vec<Task>, DbError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, completed, created_at, completed_at,
                    scheduled_date, estimated_mins, notes, latest_focus_at, latest_pause_at,
                    elapsed_secs, project_id
             FROM tasks ORDER BY sort_order, id",
        )?;
        let tasks = stmt
            .query_map([], |row| task_from_row(row))?
            .collect::<SqlResult<Vec<_>>>()?;
        Ok(tasks)
    }

    pub fn task_done(&self, id: i64) -> Result<(), DbError> {
        // Stop active session for this task before completing
        if let Ok(Some(session)) = self.session_active() {
            if session.task_id == Some(id) {
                let _ = self.session_end_by_id(session.id);
            }
        }
        let now = Utc::now();
        // Push to bottom of sort order when completing
        let bottom_order: i64 = self.conn.query_row(
            "SELECT COALESCE(MAX(sort_order), 0) + 1 FROM tasks WHERE id != ?1",
            params![id],
            |row| row.get(0),
        ).unwrap_or(0);
        let rows = self.conn.execute(
            "UPDATE tasks SET completed = 1, completed_at = ?1, sort_order = ?2 WHERE id = ?3 AND completed = 0",
            params![now.to_rfc3339(), bottom_order, id],
        )?;
        if rows == 0 {
            return Err(DbError::TaskNotFound(id));
        }
        Ok(())
    }

    pub fn task_undone(&self, id: i64) -> Result<(), DbError> {
        let rows = self.conn.execute(
            "UPDATE tasks SET completed = 0, completed_at = NULL WHERE id = ?1",
            params![id],
        )?;
        if rows == 0 {
            return Err(DbError::TaskNotFound(id));
        }
        Ok(())
    }

    pub fn task_edit(&self, id: i64, patch: TaskPatch) -> Result<(), DbError> {
        let exists: bool = self.conn.query_row(
            "SELECT EXISTS(SELECT 1 FROM tasks WHERE id = ?1)",
            params![id],
            |row| row.get(0),
        )?;
        if !exists {
            return Err(DbError::TaskNotFound(id));
        }

        if let Some(title) = patch.title {
            self.conn.execute(
                "UPDATE tasks SET title = ?1 WHERE id = ?2",
                params![title, id],
            )?;
        }
        if let Some(date) = patch.scheduled_date {
            let s = date.map(|d| d.to_string());
            self.conn.execute(
                "UPDATE tasks SET scheduled_date = ?1 WHERE id = ?2",
                params![s, id],
            )?;
        }
        if let Some(mins) = patch.estimated_mins {
            self.conn.execute(
                "UPDATE tasks SET estimated_mins = ?1 WHERE id = ?2",
                params![mins, id],
            )?;
        }
        if let Some(notes) = patch.notes {
            self.conn.execute(
                "UPDATE tasks SET notes = ?1 WHERE id = ?2",
                params![notes, id],
            )?;
        }
        if let Some(project_id) = patch.project_id {
            self.conn.execute(
                "UPDATE tasks SET project_id = ?1 WHERE id = ?2",
                params![project_id, id],
            )?;
        }
        Ok(())
    }

    pub fn task_reorder(&self, ids: &[i64]) -> Result<(), DbError> {
        for (i, &id) in ids.iter().enumerate() {
            self.conn.execute(
                "UPDATE tasks SET sort_order = ?1 WHERE id = ?2",
                params![(i + 1) as i64, id],
            )?;
        }
        Ok(())
    }

    pub fn task_reset_time(&self, id: i64) -> Result<(), DbError> {
        let rows = self.conn.execute(
            "UPDATE tasks SET elapsed_secs = 0 WHERE id = ?1",
            params![id],
        )?;
        if rows == 0 {
            return Err(DbError::TaskNotFound(id));
        }
        // Also delete all completed sessions for this task
        self.conn.execute(
            "DELETE FROM focus_sessions WHERE task_id = ?1 AND ended_at IS NOT NULL",
            params![id],
        )?;
        Ok(())
    }

    pub fn task_delete(&self, id: i64) -> Result<(), DbError> {
        // Remove sessions referencing this task before deleting it
        self.conn.execute(
            "DELETE FROM focus_sessions WHERE task_id = ?1",
            params![id],
        )?;
        let rows = self
            .conn
            .execute("DELETE FROM tasks WHERE id = ?1", params![id])?;
        if rows == 0 {
            return Err(DbError::TaskNotFound(id));
        }
        Ok(())
    }

    // ── Sessions ───────────────────────────────────────────────────────────

    pub fn session_start(&self, task_id: i64) -> Result<FocusSession, DbError> {
        if let Some(active) = self.session_active()? {
            self.session_end_by_id(active.id)?;
        }
        let now = Utc::now();
        self.conn.execute(
            "INSERT INTO focus_sessions (task_id, started_at) VALUES (?1, ?2)",
            params![task_id, now.to_rfc3339()],
        )?;
        let id = self.conn.last_insert_rowid();
        // Track latest_focus_at on the task
        self.conn.execute(
            "UPDATE tasks SET latest_focus_at = ?1 WHERE id = ?2",
            params![now.to_rfc3339(), task_id],
        )?;
        Ok(FocusSession {
            id,
            task_id: Some(task_id),
            started_at: now,
            ended_at: None,
            paused_at: None,
        })
    }

    pub fn session_active(&self) -> Result<Option<FocusSession>, DbError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, task_id, started_at, ended_at, paused_at
             FROM focus_sessions WHERE ended_at IS NULL LIMIT 1",
        )?;
        let mut rows = stmt.query_map([], |row| {
            Ok(FocusSession {
                id: row.get(0)?,
                task_id: row.get(1)?,
                started_at: parse_dt(row.get::<_, String>(2)?),
                ended_at: row.get::<_, Option<String>>(3)?.map(parse_dt),
                paused_at: row.get::<_, Option<String>>(4)?.map(parse_dt),
            })
        })?;
        Ok(rows.next().transpose()?)
    }

    pub fn session_pause(&self) -> Result<FocusSession, DbError> {
        let s = self.session_active()?.ok_or(DbError::NoActiveSession)?;
        if s.paused_at.is_some() {
            return Err(DbError::AlreadyPaused);
        }
        let now = Utc::now();
        self.conn.execute(
            "UPDATE focus_sessions SET paused_at = ?1 WHERE id = ?2",
            params![now.to_rfc3339(), s.id],
        )?;
        // Track latest_pause_at on the task
        if let Some(task_id) = s.task_id {
            self.conn.execute(
                "UPDATE tasks SET latest_pause_at = ?1 WHERE id = ?2",
                params![now.to_rfc3339(), task_id],
            )?;
        }
        Ok(FocusSession { paused_at: Some(now), ..s })
    }

    pub fn session_resume(&self) -> Result<FocusSession, DbError> {
        let s = self.session_active()?.ok_or(DbError::NoActiveSession)?;
        let paused_at = s.paused_at.ok_or(DbError::NotPaused)?;
        let now = Utc::now();
        let pause_duration = now.signed_duration_since(paused_at);
        let new_started = s.started_at + pause_duration;
        self.conn.execute(
            "UPDATE focus_sessions SET started_at = ?1, paused_at = NULL WHERE id = ?2",
            params![new_started.to_rfc3339(), s.id],
        )?;
        Ok(FocusSession { started_at: new_started, paused_at: None, ..s })
    }

    pub fn session_stop(&self) -> Result<FocusSession, DbError> {
        let s = self.session_active()?.ok_or(DbError::NoActiveSession)?;
        self.session_end_by_id(s.id)?;
        let now = Utc::now();
        Ok(FocusSession { ended_at: Some(now), paused_at: None, ..s })
    }

    fn session_end_by_id(&self, id: i64) -> SqlResult<()> {
        let (task_id, started_at_s): (Option<i64>, String) = self.conn.query_row(
            "SELECT task_id, started_at FROM focus_sessions WHERE id = ?1",
            params![id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        let now = Utc::now();
        let started_at = parse_dt(started_at_s);
        let duration_secs = now.signed_duration_since(started_at).num_seconds().max(0);
        self.conn.execute(
            "UPDATE focus_sessions SET ended_at = ?1, paused_at = NULL WHERE id = ?2",
            params![now.to_rfc3339(), id],
        )?;
        if let Some(tid) = task_id {
            self.conn.execute(
                "UPDATE tasks SET elapsed_secs = elapsed_secs + ?1 WHERE id = ?2",
                params![duration_secs, tid],
            )?;
        }
        Ok(())
    }

    pub fn status(&self) -> Result<StatusOutput, DbError> {
        let session = self.session_active()?;
        match session {
            None => Ok(StatusOutput {
                active: false,
                paused: false,
                session: None,
                task: None,
                elapsed_secs: 0,
            }),
            Some(s) => {
                let task = s
                    .task_id
                    .map(|tid| self.task_by_id(tid))
                    .transpose()?
                    .flatten();
                let current_elapsed = session::elapsed_secs(&s);
                let task_elapsed = task.as_ref().map(|t| t.elapsed_secs).unwrap_or(0);
                let paused = session::is_paused(&s);
                Ok(StatusOutput {
                    active: true,
                    paused,
                    elapsed_secs: task_elapsed + current_elapsed,
                    task,
                    session: Some(s),
                })
            }
        }
    }

    fn task_by_id(&self, id: i64) -> Result<Option<Task>, DbError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, completed, created_at, completed_at,
                    scheduled_date, estimated_mins, notes, latest_focus_at, latest_pause_at,
                    elapsed_secs, project_id
             FROM tasks WHERE id = ?1",
        )?;
        let mut rows = stmt.query_map(params![id], |row| task_from_row(row))?;
        Ok(rows.next().transpose()?)
    }

    // ── Projects ───────────────────────────────────────────────────────────

    pub fn project_add(
        &self,
        name: &str,
        color: &str,
        status: &str,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
        estimated_mins: Option<i64>,
    ) -> Result<Project, DbError> {
        let now = Utc::now();
        self.conn.execute(
            "INSERT INTO projects (name, color, status, start_date, end_date, estimated_mins, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                name, color, status,
                start_date.map(|d| d.to_string()),
                end_date.map(|d| d.to_string()),
                estimated_mins,
                now.to_rfc3339()
            ],
        )?;
        let id = self.conn.last_insert_rowid();
        Ok(Project {
            id, name: name.to_string(), color: color.to_string(),
            status: status.to_string(), start_date, end_date,
            estimated_mins, created_at: now,
        })
    }

    pub fn project_list(&self) -> Result<Vec<Project>, DbError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, name, color, status, start_date, end_date, estimated_mins, created_at
             FROM projects ORDER BY id",
        )?;
        let projects = stmt
            .query_map([], |row| project_from_row(row))?
            .collect::<SqlResult<Vec<_>>>()?;
        Ok(projects)
    }

    pub fn project_edit(&self, id: i64, patch: ProjectPatch) -> Result<(), DbError> {
        let exists: bool = self.conn.query_row(
            "SELECT EXISTS(SELECT 1 FROM projects WHERE id = ?1)",
            params![id], |row| row.get(0),
        )?;
        if !exists { return Err(DbError::TaskNotFound(id)); }
        if let Some(name) = patch.name {
            self.conn.execute("UPDATE projects SET name = ?1 WHERE id = ?2", params![name, id])?;
        }
        if let Some(color) = patch.color {
            self.conn.execute("UPDATE projects SET color = ?1 WHERE id = ?2", params![color, id])?;
        }
        if let Some(status) = patch.status {
            self.conn.execute("UPDATE projects SET status = ?1 WHERE id = ?2", params![status, id])?;
        }
        if let Some(d) = patch.start_date {
            self.conn.execute("UPDATE projects SET start_date = ?1 WHERE id = ?2", params![d.map(|d| d.to_string()), id])?;
        }
        if let Some(d) = patch.end_date {
            self.conn.execute("UPDATE projects SET end_date = ?1 WHERE id = ?2", params![d.map(|d| d.to_string()), id])?;
        }
        if let Some(m) = patch.estimated_mins {
            self.conn.execute("UPDATE projects SET estimated_mins = ?1 WHERE id = ?2", params![m, id])?;
        }
        Ok(())
    }

    pub fn project_delete(&self, id: i64) -> Result<(), DbError> {
        // Clear project_id on tasks (don't delete tasks)
        self.conn.execute("UPDATE tasks SET project_id = NULL WHERE project_id = ?1", params![id])?;
        let rows = self.conn.execute("DELETE FROM projects WHERE id = ?1", params![id])?;
        if rows == 0 { return Err(DbError::TaskNotFound(id)); }
        Ok(())
    }
}

fn task_from_row(row: &rusqlite::Row<'_>) -> SqlResult<Task> {
    Ok(Task {
        id: row.get(0)?,
        title: row.get(1)?,
        completed: row.get::<_, i32>(2)? != 0,
        created_at: parse_dt(row.get::<_, String>(3)?),
        completed_at: row.get::<_, Option<String>>(4)?.map(parse_dt),
        scheduled_date: row.get::<_, Option<String>>(5)?.and_then(|s| s.parse().ok()),
        estimated_mins: row.get(6)?,
        notes: row.get(7)?,
        latest_focus_at: row.get::<_, Option<String>>(8)?.map(parse_dt),
        latest_pause_at: row.get::<_, Option<String>>(9)?.map(parse_dt),
        elapsed_secs: row.get::<_, i64>(10).unwrap_or(0).max(0) as u64,
        project_id: row.get(11).unwrap_or(None),
    })
}

fn project_from_row(row: &rusqlite::Row<'_>) -> SqlResult<Project> {
    Ok(Project {
        id: row.get(0)?,
        name: row.get(1)?,
        color: row.get(2)?,
        status: row.get(3)?,
        start_date: row.get::<_, Option<String>>(4)?.and_then(|s| s.parse().ok()),
        end_date: row.get::<_, Option<String>>(5)?.and_then(|s| s.parse().ok()),
        estimated_mins: row.get(6)?,
        created_at: parse_dt(row.get::<_, String>(7)?),
    })
}

fn parse_dt(s: String) -> DateTime<Utc> {
    s.parse::<DateTime<Utc>>().unwrap_or_else(|_| Utc::now())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn db() -> Db {
        Db::open_in_memory().unwrap()
    }

    #[test]
    fn task_crud() {
        let db = db();
        let t = db.task_add("Buy milk", None, None, None).unwrap();
        assert_eq!(t.title, "Buy milk");
        assert!(!t.completed);
        assert!(t.scheduled_date.is_none());

        let list = db.task_list().unwrap();
        assert_eq!(list.len(), 1);

        db.task_done(t.id).unwrap();
        let list = db.task_list().unwrap();
        assert!(list[0].completed);

        db.task_delete(t.id).unwrap();
        assert!(db.task_list().unwrap().is_empty());
    }

    #[test]
    fn task_with_fields() {
        let db = db();
        let date = "2026-09-10".parse::<NaiveDate>().unwrap();
        let t = db.task_add("Study Rust", Some(date), Some(90), Some("Focus on lifetimes")).unwrap();
        assert_eq!(t.scheduled_date, Some(date));
        assert_eq!(t.estimated_mins, Some(90));
        assert_eq!(t.notes.as_deref(), Some("Focus on lifetimes"));

        // Edit — only change title and clear date
        db.task_edit(t.id, TaskPatch {
            title: Some("Study Rust deeply".to_string()),
            scheduled_date: Some(None),
            estimated_mins: None,
            notes: None,
            project_id: None,
        }).unwrap();

        let list = db.task_list().unwrap();
        assert_eq!(list[0].title, "Study Rust deeply");
        assert!(list[0].scheduled_date.is_none());
        assert_eq!(list[0].estimated_mins, Some(90)); // unchanged
    }

    #[test]
    fn session_lifecycle() {
        let db = db();
        let task = db.task_add("Focus task", None, None, None).unwrap();

        let s = db.session_start(task.id).unwrap();
        assert!(s.ended_at.is_none());

        // latest_focus_at should be set
        let tasks = db.task_list().unwrap();
        assert!(tasks[0].latest_focus_at.is_some());

        db.session_pause().unwrap();

        // latest_pause_at should be set
        let tasks = db.task_list().unwrap();
        assert!(tasks[0].latest_pause_at.is_some());

        db.session_resume().unwrap();
        db.session_stop().unwrap();
        assert!(!db.status().unwrap().active);
    }

    #[test]
    fn task_edit_only_notes() {
        let db = db();
        let t = db.task_add("Old title", None, None, None).unwrap();
        db.task_edit(t.id, TaskPatch {
            title: None,
            scheduled_date: None,
            estimated_mins: Some(Some(60)),
            notes: Some(Some("My note".to_string())),
            project_id: None,
        }).unwrap();
        let list = db.task_list().unwrap();
        assert_eq!(list[0].title, "Old title"); // unchanged
        assert_eq!(list[0].estimated_mins, Some(60));
        assert_eq!(list[0].notes.as_deref(), Some("My note"));
    }
}
