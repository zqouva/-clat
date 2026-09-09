//! --> ["éclat"]
//!
//! --> a high-performance roblox asset upload engine.
//! --> made by Makel / Savi (@sacredludt · @.makel).
//!
//! --> this file is the conductor: it wakes the banner,
//! --> ingests the cookie, boots the engine, and opens the uplink.
//! --> every rite below lives in the atelier; nothing loiters here.

mod atelier;

use std::io::{self, Write};
use std::path::Path;

use colored::Colorize;

use crate::atelier::banner;
use crate::atelier::client::Engine;

const COOKIE_FILE: &str = "cookie.txt";
const COOKIE_PLACEHOLDER: &str = "PASTE_YOUR_ROBLOSECURITY_HERE";

const COOKIE_SEED: &str = "# --> [\"éclat cookie\"]\n# --> paste your raw .ROBLOSECURITY token on the line below, then run the engine.\n# --> the engine trims spaces, quotes and accidental prefixes for you.\n# --> NEVER share this file. anyone holding it can wear your account.\nPASTE_YOUR_ROBLOSECURITY_HERE\n";

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("{} {err}", "[éclat/death]".red().bold());
        std::process::exit(1);
    }
}

async fn run() -> Result<(), String> {
    banner::print_title();

    let cookie = ingest_cookie().await?;
    banner::stage("cookie", "ingested + sanitized");

    let engine = Engine::boot(cookie).await?;
    crate::atelier::server::serve(engine).await
}

// --> ["cookie ingestion"]
// --> cookie.txt, or a single paste the engine keeps warm afterwards.
async fn ingest_cookie() -> Result<String, String> {
    if !Path::new(COOKIE_FILE).exists() {
        tokio::fs::write(COOKIE_FILE, COOKIE_SEED)
            .await
            .map_err(|e| format!("[éclat/boot] cannot seed {COOKIE_FILE}: {e}"))?;
        banner::warn(format!("{COOKIE_FILE} did not exist — one was seeded for you."));
    }
    let raw = tokio::fs::read_to_string(COOKIE_FILE)
        .await
        .map_err(|e| format!("[éclat/boot] cannot read {COOKIE_FILE}: {e}"))?;
    if let Some(token) = first_usable_line(&raw) {
        if token != COOKIE_PLACEHOLDER {
            return Ok(token);
        }
    }
    prompt_cookie().await
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

async fn prompt_cookie() -> Result<String, String> {
    println!(
        "  {} no cookie sleeps in {COOKIE_FILE} — paste it once, the engine will keep it.",
        "[éclat/boot]".magenta().bold()
    );
    print!("ROBLOSECURITY: ");
    io::stdout()
        .flush()
        .map_err(|e| format!("[éclat/boot] cannot address the terminal: {e}"))?;
    let mut line = String::new();
    io::stdin()
        .read_line(&mut line)
        .map_err(|e| format!("[éclat/boot] cannot hear the terminal: {e}"))?;
    let token = line.trim().to_owned();
    if token.is_empty() || token == COOKIE_PLACEHOLDER {
        return Err("[éclat/boot] no .ROBLOSECURITY was given — the engine cannot wake.".to_owned());
    }
    tokio::fs::write(COOKIE_FILE, format!("{token}\n"))
        .await
        .map_err(|e| format!("[éclat/boot] cannot persist {COOKIE_FILE}: {e}"))?;
    Ok(token)
}
