use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde_json::{json, Value};

use crate::atelier::banner;
use crate::atelier::client::Engine;

const KEY_FILE: &str = "api_key.txt";
const CANDIDATES: [&str; 2] = [
    "https://apis.roblox.com/api-keys/v1/api-keys",
    "https://apis.roblox.com/api-keys/v1/apiKeys",
];

// --> [`secret`]
const SECRET_PATHS: [&[&str]; 10] = [
    &["apiKey"],
    &["api_key"],
    &["key"],
    &["secret"],
    &["token"],
    &["keySecret"],
    &["secretKey"],
    &["data", "apiKey"],
    &["data", "key"],
    &["result", "apiKey"],
];

fn dig<'a>(value: &'a Value, path: &[&str]) -> Option<&'a str> {
    let mut node = value;
    for key in path {
        node = node.get(*key)?;
    }
    node.as_str()
}

fn sniff_secret(text: &str) -> Option<String> {
    let value: Value = serde_json::from_str(text).ok()?;
    for path in SECRET_PATHS {
        if let Some(secret) = dig(&value, path) {
            if !secret.trim().is_empty() {
                return Some(secret.trim().to_owned());
            }
        }
    }
    None
}

fn snippet(text: &str) -> String {
    let flat: String = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if flat.chars().count() > 260 {
        format!("{}…", flat.chars().take(260).collect::<String>())
    } else {
        flat
    }
}

// --> [`note`]
fn keyless_note(why: String) {
    banner::warn(format!("opencloud keyless: {why}"));
    banner::warn("hand-mint: create.roblox.com → dashboard → credentials → create api key → assets system → write ops → experience+ip restricts OFF → save & generate → paste into api_key.txt → reupload again, no restart needed");
}

// --> [`mint`]
pub async fn provision(engine: &Engine) -> Option<String> {
    banner::stage("opencloud", "no key saved — minting one from your cookie...");
    let cookie = match engine.cookie.header().await {
        Ok(header) => header,
        Err(e) => {
            keyless_note(format!("cannot read the saved cookie ({e})"));
            return None;
        }
    };
    let body = json!({
        "name": "eclat-engine",
        "enabled": true,
        "scopes": [{
            "name": "asset",
            "operations": ["write"],
            "userIds": ["*"],
            "groupIds": ["*"],
        }],
    });
    for url in CANDIDATES {
        match create(engine, &cookie, url, &body).await {
            Mint::Key(secret) => return Some(secret),
            Mint::Missing => continue,
            Mint::Dead(end) => {
                keyless_note(end);
                return None;
            }
        }
    }
    keyless_note("key service answered 404 everywhere — hand-mint for now".to_owned());
    None
}

enum Mint {
    Key(String),
    Missing,
    Dead(String),
}

// --> [`create`]
async fn create(engine: &Engine, cookie: &HeaderValue, url: &str, body: &Value) -> Mint {
    for attempt in 0..2 {
        let csrf = engine.csrf.get().await;
        let sent = engine
            .http
            .post(url)
            .header(COOKIE, cookie.clone())
            .header("x-csrf-token", csrf)
            .json(body)
            .send()
            .await;
        let res = match sent {
            Ok(res) => res,
            Err(e) => return Mint::Dead(format!("key service unreachable ({e})")),
        };
        let status = res.status();
        let text = res.text().await.unwrap_or_default();
        if status.is_success() {
            match sniff_secret(&text) {
                Some(secret) => {
                    match tokio::fs::write(KEY_FILE, format!("{secret}\n")).await {
                        Ok(_) => banner::ok("opencloud key minted + saved to api_key.txt"),
                        Err(e) => banner::warn(format!("key minted but {KEY_FILE} would not save: {e}")),
                    }
                    return Mint::Key(secret);
                }
                None => {
                    return Mint::Dead(format!(
                        "mint answered {status} with no readable secret: {}",
                        snippet(&text)
                    ));
                }
            }
        }
        if status == StatusCode::NOT_FOUND {
            banner::warn(format!("key mint {url} → 404 {}", snippet(&text)));
            return Mint::Missing;
        }
        if status == StatusCode::FORBIDDEN && text.contains("Token Validation Failed") && attempt == 0 {
            let _ = engine.csrf.refresh().await;
            continue;
        }
        if status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN {
            return Mint::Dead(format!("roblox refused the mint ({status}): {}", snippet(&text)));
        }
        return Mint::Dead(format!("key mint {url} → {status} {}", snippet(&text)));
    }
    Mint::Dead("mint unanswered".to_owned())
}
