
mod atelier;

use std::path::Path;

use colored::Colorize;

use crate::atelier::banner;
use crate::atelier::client::Engine;
use crate::atelier::loader;

const COOKIE_FILE: &str = "cookie.txt";
const COOKIE_PLACEHOLDER: &str = "PASTE_YOUR_ROBLOSECURITY_HERE";

const COOKIE_SEED: &str = "# --> [`eclat cookie`]\n# paste your raw .ROBLOSECURITY token on the line below, then run the engine.\n# NEVER share this file. anyone holding it can wear your account.\nPASTE_YOUR_ROBLOSECURITY_HERE\n";

#[tokio::main]
async fn main() {
    let _ = enable_ansi_support::enable_ansi_support();
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--version" || a == "-V") {
        println!("eclat v{}", banner::ENGINE_VERSION);
        return;
    }
    if args.iter().any(|a| a == "--help" || a == "-h") {
        println!("eclat v{} — put cookie.txt next to the binary and run it.", banner::ENGINE_VERSION);
        return;
    }
    if let Err(err) = run().await {
        eprintln!("{} {err}", "[éclat/fatal]".red().bold());
        std::process::exit(1);
    }
}

async fn run() -> Result<(), String> {
    banner::print_title();
    loader::play();

    let cookie = ingest_cookie().await?;
    banner::stage("cookie", "loaded + cleaned");

    let engine = Engine::boot(cookie).await?;
    crate::atelier::server::serve(engine).await
}

// --> [`cookie ingestion`]
async fn ingest_cookie() -> Result<String, String> {
    if !Path::new(COOKIE_FILE).exists() {
        tokio::fs::write(COOKIE_FILE, COOKIE_SEED)
            .await
            .map_err(|e| format!("[éclat/boot] cannot write {COOKIE_FILE}: {e}"))?;
        banner::warn(format!("{COOKIE_FILE} missing — wrote a blank one. paste your cookie in it."));
    }
    let raw = tokio::fs::read_to_string(COOKIE_FILE)
        .await
        .map_err(|e| format!("[éclat/boot] cannot read {COOKIE_FILE}: {e}"))?;
    if let Some(token) = first_usable_line(&raw) {
        if token != COOKIE_PLACEHOLDER {
            return Ok(token);
        }
    }
    loader::ask(COOKIE_FILE, COOKIE_PLACEHOLDER).await
}

fn first_usable_line(raw: &str) -> Option<String> {
    for line in raw.lines() {
        let text = line.trim();
        if text.is_empty() || text.starts_with('#') {
            continue;
        }
        return Some(text.to_owned());
    }
    None
}
