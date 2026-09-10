use std::io::{self, IsTerminal, Write};
use std::time::Duration;

use colored::Colorize;

use crate::atelier::banner;
use crate::atelier::client::Engine;
use crate::atelier::server::{COMPAT_PORT, PRIMARY_PORT};

const TICKS: u32 = 14;
const FRAMES: [&str; 4] = ["◐", "◓", "◑", "◒"];
const STRIPE: &str = "//////////////////////////////////////////";
const MENU_TOP: &str = "╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲";
const MENU_BOT: &str = "╲━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╱";

// --> [`load`]
pub fn play() {
    if !io::stdout().is_terminal() {
        return;
    }
    println!("  {}", STRIPE.blue().bold());
    print!("\x1b[?25l");
    for tick in 0..TICKS {
        let frame = FRAMES[(tick % 4) as usize];
        let dots = ".".repeat((1 + tick % 3) as usize);
        let filled = ((tick + 1) * 24 / TICKS) as usize;
        let pct = (tick + 1) * 100 / TICKS;
        print!(
            "\r  {}  {}{}  [{}{}]  {}%   ",
            frame.bright_blue().bold(),
            "NOW LOADING".bright_white().bold(),
            dots.bright_white().bold(),
            "█".repeat(filled).blue().bold(),
            "░".repeat(24 - filled).bright_black(),
            format!("{pct}").white()
        );
        let _ = io::stdout().flush();
        std::thread::sleep(Duration::from_millis(120));
    }
    println!();
    println!("  {}", STRIPE.blue().bold());
    print!("\x1b[?25h");
    let _ = io::stdout().flush();
}

// --> [`menu`]
pub async fn menu(engine: &Engine, cookie_saved: bool) {
    let key = if engine.opencloud_key.read().await.is_some() {
        "key ready"
    } else {
        "key auto on demand"
    };
    let rows = [
        ("ENGINE", format!("v{}", banner::ENGINE_VERSION)),
        ("COOKIE", if cookie_saved { "saved ✓".to_owned() } else { "fresh ✓".to_owned() }),
        ("API KEY", key.to_owned()),
        ("UPLINK", format!(":{PRIMARY_PORT} + :{COMPAT_PORT}")),
    ];
    let live = io::stdout().is_terminal();
    if live {
        print!("\x1b[?25l");
    }
    println!("  {}", MENU_TOP.blue().bold());
    for (tag, value) in rows {
        println!(
            "  {}  {}  {}  {}",
            "┃".blue().bold(),
            "▶".bright_white().bold(),
            tag.bright_blue().bold(),
            value.white()
        );
        if live {
            let _ = io::stdout().flush();
            tokio::time::sleep(Duration::from_millis(90)).await;
        }
    }
    println!("  {}", MENU_BOT.blue().bold());
    println!();
    if live {
        print!("\x1b[?25h");
        let _ = io::stdout().flush();
    }
}

// --> [`ask`]
pub async fn ask(cookie_file: &str, placeholder: &str) -> Result<String, String> {
    println!(
        "  {} no cookie saved — paste it once. it stays on this machine.",
        "[éclat/load]".blue().bold()
    );
    print!("  ROBLOSECURITY: ");
    io::stdout()
        .flush()
        .map_err(|e| format!("[éclat/load] cannot flush the terminal: {e}"))?;
    let mut line = String::new();
    io::stdin()
        .read_line(&mut line)
        .map_err(|e| format!("[éclat/load] cannot read the terminal: {e}"))?;
    let token = line.trim().to_owned();
    if token.is_empty() || token == placeholder {
        return Err("[éclat/load] no .ROBLOSECURITY given.".to_owned());
    }
    tokio::fs::write(cookie_file, format!("{token}\n"))
        .await
        .map_err(|e| format!("[éclat/load] cannot save {cookie_file}: {e}"))?;
    Ok(token)
}
