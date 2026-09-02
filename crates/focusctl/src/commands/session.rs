use anyhow::Result;
use focus_db::Db;

pub fn status(db: &Db, json: bool) -> Result<()> {
    let s = db.status()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&s)?);
    } else {
        println!("{s}");
    }
    Ok(())
}

pub fn start(db: &Db, task_id: i64, json: bool) -> Result<()> {
    let s = db.session_start(task_id)?;
    if json {
        println!("{}", serde_json::to_string_pretty(&s)?);
    } else {
        println!("Sessão iniciada para tarefa #{task_id}");
    }
    Ok(())
}

pub fn pause(db: &Db, json: bool) -> Result<()> {
    let s = db.session_pause()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&s)?);
    } else {
        println!("Sessão pausada");
    }
    Ok(())
}

pub fn resume(db: &Db, json: bool) -> Result<()> {
    let s = db.session_resume()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&s)?);
    } else {
        println!("Sessão retomada");
    }
    Ok(())
}

pub fn stop(db: &Db, json: bool) -> Result<()> {
    let s = db.session_stop()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&s)?);
    } else {
        println!("Sessão encerrada");
    }
    Ok(())
}
