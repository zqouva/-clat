
use colored::Colorize;

pub const ENGINE_VERSION: &str = env!("CARGO_PKG_VERSION");

pub const PROTOCOL_VERSION: &str = "1.3.1";

const PANEL_TOP: &str = "╱━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╲";
const PANEL_BOT: &str = "╲━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╱";

pub fn print_title() {
    println!("  {}", PANEL_TOP.blue().bold());
    println!(
        "  {}  {}  {}",
        "┃".blue().bold(),
        "ÉCLAT".bright_white().bold(),
        format!("v{ENGINE_VERSION}").white()
    );
    println!("  {}  {}", "┃".blue().bold(), "asset uploader".bright_blue());
    println!(
        "  {}  {}",
        "┃".blue().bold(),
        "Makel / Savi (@sacredludt · @.makel)".white()
    );
    println!("  {}", PANEL_BOT.blue().bold());
    println!();
}

pub fn stage(name: &str, message: impl AsRef<str>) {
    println!(
        "  {} {}  {}",
        "◆".blue().bold(),
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

pub fn swapped(current: u32, total: u32, name: &str, old_id: i64, new_id: i64) {
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
