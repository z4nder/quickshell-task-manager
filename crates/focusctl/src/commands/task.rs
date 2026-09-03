use anyhow::Result;
use chrono::NaiveDate;
use focus_db::{Db, TaskPatch};

pub fn add(
    db: &Db,
    title: &str,
    date: Option<NaiveDate>,
    estimated_mins: Option<i64>,
    notes: Option<&str>,
    json: bool,
) -> Result<()> {
    let t = db.task_add(title, date, estimated_mins, notes)?;
    if json {
        println!("{}", serde_json::to_string_pretty(&t)?);
    } else {
        println!("Tarefa criada: {t}");
    }
    Ok(())
}

pub fn list(db: &Db, json: bool) -> Result<()> {
    let tasks = db.task_list()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&tasks)?);
    } else if tasks.is_empty() {
        println!("Nenhuma tarefa cadastrada.");
    } else {
        for t in &tasks {
            println!("{t}");
            if let Some(n) = &t.notes {
                println!("   ↳ {n}");
            }
        }
    }
    Ok(())
}

pub fn done(db: &Db, id: i64) -> Result<()> {
    db.task_done(id)?;
    println!("Tarefa #{id} concluída");
    Ok(())
}

pub fn undone(db: &Db, id: i64) -> Result<()> {
    db.task_undone(id)?;
    println!("Tarefa #{id} reaberta");
    Ok(())
}

pub fn edit(db: &Db, id: i64, patch: TaskPatch) -> Result<()> {
    db.task_edit(id, patch)?;
    println!("Tarefa #{id} atualizada");
    Ok(())
}

pub fn delete(db: &Db, id: i64) -> Result<()> {
    db.task_delete(id)?;
    println!("Tarefa #{id} removida");
    Ok(())
}
