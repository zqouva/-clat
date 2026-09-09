//! --> ["banner"]
//!
//! --> magenta ink for the terminal liturgy.
//! --> the title, the pipeline psalms, and the attribution verse
//! --> the license asks us to sing on every execution. we sing gladly.

use colored::Colorize;

pub const ENGINE_VERSION: &str = env!("CARGO_PKG_VERSION");

/// --> ["protocol"]
/// --> éclat speaks the kartFr plugin tongue (1.3.1) fluently,
/// --> plus its own verses (/upload · /cookie · /health · /status).
pub const PROTOCOL_VERSION: &str = "1.3.1";

const TITLE: &str = r#"
  ███████   ██████  ██           █    ███████
  ██       ██       ██          █ █      █
  █████    ██       ██         █████     █
  ██       ██       ██        ██   ██    █
  ███████   ██████  ███████   ██   ██    █
"#;

/// --> ["title"]
pub fn print_title() {
    println!("{}", TITLE.magenta().bold());
    println!(
        "  {}  {}  {}",
        "éclat".magenta().bold(),
        format!("v{ENGINE_VERSION}").white(),
        "· the soul of the upload".bright_magenta()
    );
    println!(
        "  {}  Makel / Savi (@sacredludt · @.makel)",
        "◆".magenta()
    );
    println!();
}

/// --> ["psalms"]
/// --> one line per pipeline station, tracked as the engine wakes.
pub fn stage(name: &str, message: impl AsRef<str>) {
    println!(
        "  {} {}  {}",
        "◆".magenta().bold(),
        name.bright_white().bold(),
        message.as_ref().bright_black()
    );
}

pub fn ok(message: impl AsRef<str>) {
    println!("  {} {}", "✓".green().bold(), message.as_ref().green());
}

pub fn info(message: impl AsRef<str>) {
    println!("  {} {}", "·".cyan(), message.as_ref().bright_black());
}

pub fn warn(message: impl AsRef<str>) {
    println!("  {} {}", "!".yellow().bold(), message.as_ref().yellow());
}

pub fn err(message: impl AsRef<str>) {
    println!("  {} {}", "✗".red().bold(), message.as_ref().red());
}

/// --> ["carried"]
/// --> the success verse for one asset finding its new home.
pub fn carried(current: u32, total: u32, name: &str, old_id: i64, new_id: i64) {
    println!(
        "  {} [{}/{}] {} ({} → {})",
        "✓".green().bold(),
        current,
        total,
        name.bright_white(),
        old_id,
        new_id
    );
}
