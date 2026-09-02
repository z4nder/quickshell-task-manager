use chrono::Utc;

use crate::models::FocusSession;

/// Elapsed active seconds for a session.
/// If paused: `paused_at - started_at`.
/// If running: `now - started_at`.
/// `started_at` is adjusted on resume to absorb pause duration, so this
/// formula stays correct across multiple pause/resume cycles.
pub fn elapsed_secs(session: &FocusSession) -> u64 {
    let reference = session.paused_at.unwrap_or_else(Utc::now);
    let diff = reference.signed_duration_since(session.started_at);
    diff.num_seconds().max(0) as u64
}

pub fn is_paused(session: &FocusSession) -> bool {
    session.ended_at.is_none() && session.paused_at.is_some()
}

pub fn is_running(session: &FocusSession) -> bool {
    session.ended_at.is_none() && session.paused_at.is_none()
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, Utc};
    use crate::models::FocusSession;

    fn make_session(
        started_offset_secs: i64,
        ended: bool,
        paused_offset_secs: Option<i64>,
    ) -> FocusSession {
        let now = Utc::now();
        let started_at = now - Duration::seconds(started_offset_secs);
        let ended_at = if ended { Some(now) } else { None };
        let paused_at = paused_offset_secs
            .map(|s| now - Duration::seconds(s));
        FocusSession { id: 1, task_id: None, started_at, ended_at, paused_at }
    }

    #[test]
    fn elapsed_running() {
        let s = make_session(120, false, None);
        let e = elapsed_secs(&s);
        assert!((118..=122).contains(&e), "elapsed={e}");
    }

    #[test]
    fn elapsed_paused() {
        // started 200s ago, paused 50s ago → active time = 150s
        let s = make_session(200, false, Some(50));
        let e = elapsed_secs(&s);
        assert!((148..=152).contains(&e), "elapsed={e}");
    }

    #[test]
    fn is_running_and_paused() {
        let running = make_session(60, false, None);
        let paused = make_session(60, false, Some(10));
        assert!(is_running(&running));
        assert!(!is_paused(&running));
        assert!(is_paused(&paused));
        assert!(!is_running(&paused));
    }
}
