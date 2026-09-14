use anyhow::Result;
use chrono::NaiveDate;
use focus_db::{Db, ProjectPatch};

pub fn add(
    db: &Db,
    name: &str,
    color: &str,
    status: &str,
    start_date: Option<NaiveDate>,
    end_date: Option<NaiveDate>,
    estimated_mins: Option<i64>,
    json: bool,
) -> Result<()> {
    let p = db.project_add(name, color, status, start_date, end_date, estimated_mins)?;
    if json {
        println!("{}", serde_json::to_string_pretty(&p)?);
    } else {
        println!("Projeto criado: {p}");
    }
    Ok(())
}

pub fn list(db: &Db, json: bool) -> Result<()> {
    let projects = db.project_list()?;
    if json {
        println!("{}", serde_json::to_string_pretty(&projects)?);
    } else if projects.is_empty() {
        println!("Nenhum projeto cadastrado.");
    } else {
        for p in &projects {
            println!("{p}");
        }
    }
    Ok(())
}

pub fn edit(db: &Db, id: i64, patch: ProjectPatch) -> Result<()> {
    db.project_edit(id, patch)?;
    println!("Projeto #{id} atualizado");
    Ok(())
}

pub fn delete(db: &Db, id: i64) -> Result<()> {
    db.project_delete(id)?;
    println!("Projeto #{id} removido");
    Ok(())
}
