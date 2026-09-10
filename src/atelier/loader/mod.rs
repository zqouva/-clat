use std::io::{self, IsTerminal, Write};
use std::time::Duration;

use colored::Colorize;

const TICKS: u32 = 14;

const BODY: [&str; 6] = [
    "  █     █  ",
    "   █   █   ",
    "  ███████  ",
    " ██ ███ ██ ",
    "███████████",
    "█ ███████ █",
];

const LEGS: [&str; 2] = ["█ █     █ █", "   ██ ██   "];

// --> [`load`]
pub fn play() {
    if !io::stdout().is_terminal() {
        return;
    }
    print!("\x1b[?25l");
    for row in BODY.into_iter().chain(LEGS) {
        println!("  {}", row.magenta().bold());
    }
    for tick in 0..TICKS {
        let dots = ".".repeat((1 + tick % 3) as usize);
        let filled = ((tick + 1) * 24 / TICKS) as usize;
        let pct = (tick + 1) * 100 / TICKS;
        print!(
            "\r  {} {}{}  [{}{}]  {}%   ",
            "◆".magenta().bold(),
            "NOW LOADING".bright_white().bold(),
            dots.bright_white().bold(),
            "█".repeat(filled).magenta().bold(),
            "░".repeat(24 - filled).bright_black(),
            format!("{pct}").white()
        );
        let _ = io::stdout().flush();
        std::thread::sleep(Duration::from_millis(120));
    }
    println!();
    print!("\x1b[?25h");
    let _ = io::stdout().flush();
}

// --> [`ask`]
pub async fn ask(cookie_file: &str, placeholder: &str) -> Result<String, String> {
    println!(
        "  {} no cookie saved — paste it once. it stays on this machine.",
        "[éclat/load]".magenta().bold()
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
