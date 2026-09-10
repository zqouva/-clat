use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde_json::{json, Value};

use crate::atelier::banner;
use crate::atelier::client::Engine;

const KEY_SERVICE: &str = "https://apis.roblox.com/api-keys/v1/api-keys";
const KEY_FILE: &str = "api_key.txt";

// --> [`secret`]
const SECRET_PATHS: [&[&str]; 8] = [
    &["apiKey"],
    &["api_key"],
    &["key"],
    &["secret"],
    &["token"],
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
    banner::warn("hand-mint: create.roblox.com → credentials → api keys → assets read+write on your game, any-IP cidr → save as api_key.txt or ECLAT_API_KEY");
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
    if !probe(engine, &cookie).await {
        return None;
    }
    create(engine, &cookie).await
}

// --> [`probe`]
async fn probe(engine: &Engine, cookie: &HeaderValue) -> bool {
    for attempt in 0..2 {
        let csrf = engine.csrf.get().await;
        let sent = engine
            .http
            .get(KEY_SERVICE)
            .header(COOKIE, cookie.clone())
            .header("x-csrf-token", csrf)
            .send()
            .await;
        let res = match sent {
            Ok(res) => res,
            Err(e) => {
                keyless_note(format!("key service unreachable ({e})"));
                return false;
            }
        };
        let status = res.status();
        if status.is_success() || status == StatusCode::METHOD_NOT_ALLOWED {
            return true;
        }
        if status == StatusCode::NOT_FOUND {
            keyless_note("key service path 404s — roblox moved it, hand-mint for now".to_owned());
            return false;
        }
        if (status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN) && attempt == 0 {
            let _ = engine.csrf.refresh().await;
            continue;
        }
        if status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN {
            keyless_note("roblox refused the cookie on the key service — hand-mint for now".to_owned());
            return false;
        }
        let text = res.text().await.unwrap_or_default();
        keyless_note(format!("key service probe → {status} {}", snippet(&text)));
        return false;
    }
    false
}

// --> [`create`]
async fn create(engine: &Engine, cookie: &HeaderValue) -> Option<String> {
    let body = json!({
        "name": "eclat-engine",
        "description": "auto-provisioned by the eclat engine for asset uploads",
        "scopes": [{ "scope": "asset:write" }],
        "allowedCidrs": ["0.0.0.0/0"],
        "enabled": true,
    });
    for attempt in 0..2 {
        let csrf = engine.csrf.get().await;
        let sent = engine
            .http
            .post(KEY_SERVICE)
            .header(COOKIE, cookie.clone())
            .header("x-csrf-token", csrf)
            .json(&body)
            .send()
            .await;
        let res = match sent {
            Ok(res) => res,
            Err(e) => {
                keyless_note(format!("key mint request failed ({e})"));
                return None;
            }
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
                    return Some(secret);
                }
                None => {
                    banner::warn(format!(
                        "mint answered {status} with no readable secret: {}",
                        snippet(&text)
                    ));
                    keyless_note("unreadable mint answer — hand-mint for now".to_owned());
                    return None;
                }
            }
        }
        if status == StatusCode::FORBIDDEN && text.contains("Token Validation Failed") && attempt == 0 {
            let _ = engine.csrf.refresh().await;
            continue;
        }
        if status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN {
            keyless_note(format!("roblox refused the mint ({status}) — hand-mint for now"));
            return None;
        }
        banner::warn(format!("key mint → {status} {}", snippet(&text)));
        keyless_note("mint rejected — hand-mint for now".to_owned());
        return None;
    }
    None
}
