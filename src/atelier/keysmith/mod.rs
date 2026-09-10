use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde_json::{json, Value};

use crate::atelier::banner;
use crate::atelier::client::Engine;

const KEY_FILE: &str = "api_key.txt";
const INTROSPECT: &str = "https://apis.roblox.com/api-keys/v1/introspect";
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

// --> [`ensure`]
pub async fn ensure(engine: &Engine, saved: Option<String>) -> Option<String> {
    match saved {
        None => provision(engine, "no key saved").await,
        Some(key) => {
            banner::stage("opencloud", "checking the saved key...");
            match inspect(engine, &key).await {
                KeyState::Alive(note) => {
                    banner::ok(format!("saved key is alive{note}"));
                    Some(key)
                }
                KeyState::Dead(why) => {
                    banner::warn(format!("saved key is dead ({why})"));
                    provision(engine, "saved key is dead").await
                }
                KeyState::Unknown(why) => {
                    banner::warn(format!("could not verify the saved key ({why}) — keeping it"));
                    Some(key)
                }
            }
        }
    }
}

// --> [`inspect`]
enum KeyState {
    Alive(String),
    Dead(String),
    Unknown(String),
}

async fn inspect(engine: &Engine, key: &str) -> KeyState {
    let cookie = match engine.cookie.header().await {
        Ok(header) => header,
        Err(e) => return KeyState::Unknown(format!("cannot read the saved cookie ({e})")),
    };
    for field in ["apiKey", "key"] {
        let mut probe = serde_json::Map::new();
        probe.insert(field.to_owned(), json!(key));
        let csrf = engine.csrf.get().await;
        let sent = engine
            .http
            .post(INTROSPECT)
            .header(COOKIE, cookie.clone())
            .header("x-csrf-token", csrf)
            .json(&Value::Object(probe))
            .send()
            .await;
        let res = match sent {
            Ok(res) => res,
            Err(e) => return KeyState::Unknown(format!("introspect unreachable ({e})")),
        };
        let status = res.status();
        let text = res.text().await.unwrap_or_default();
        if status == StatusCode::BAD_REQUEST && field == "apiKey" {
            continue;
        }
        if status.is_success() {
            return match read_alive(&text) {
                Some(true) => KeyState::Alive(scope_note(&text)),
                Some(false) => KeyState::Dead(snippet(&text)),
                None => KeyState::Unknown(format!("unreadable answer: {}", snippet(&text))),
            };
        }
        if status == StatusCode::UNAUTHORIZED
            || status == StatusCode::FORBIDDEN
            || status == StatusCode::NOT_FOUND
        {
            return KeyState::Dead(format!("{status} {}", snippet(&text)));
        }
        return KeyState::Unknown(format!("{status} {}", snippet(&text)));
    }
    KeyState::Unknown("introspect rejected the probe shape".to_owned())
}

fn read_alive(text: &str) -> Option<bool> {
    let value: Value = serde_json::from_str(text).ok()?;
    if value.get("valid").and_then(Value::as_bool) == Some(false) {
        return Some(false);
    }
    if value.get("enabled").and_then(Value::as_bool) == Some(false) {
        return Some(false);
    }
    for flag in ["expired", "revoked", "disabled", "deleted"] {
        if value.get(flag).and_then(Value::as_bool) == Some(true) {
            return Some(false);
        }
    }
    if value.get("error").is_some() || value.get("errors").is_some() {
        return Some(false);
    }
    Some(true)
}

fn scope_note(text: &str) -> String {
    let value: Value = match serde_json::from_str(text) {
        Ok(value) => value,
        Err(_) => return String::new(),
    };
    let mut names: Vec<String> = Vec::new();
    let mut writes = 0;
    if let Some(scopes) = value.get("scopes").and_then(Value::as_array) {
        for scope in scopes {
            if let Some(name) = scope.get("name").and_then(Value::as_str) {
                names.push(name.to_owned());
            }
            if let Some(ops) = scope.get("operations").and_then(Value::as_array) {
                if ops
                    .iter()
                    .any(|op| op.as_str().map(|s| s.eq_ignore_ascii_case("write")).unwrap_or(false))
                {
                    writes += 1;
                }
            }
        }
    }
    if names.is_empty() {
        return String::new();
    }
    if writes > 0 {
        format!(" · covers {}", names.join("+"))
    } else {
        " · WARNING: no write scope seen".to_owned()
    }
}

// --> [`mint`]
pub async fn provision(engine: &Engine, context: &str) -> Option<String> {
    banner::stage("opencloud", format!("{context} — minting one from your cookie..."));
    let cookie = match engine.cookie.header().await {
        Ok(header) => header,
        Err(e) => {
            keyless_note(format!("cannot read the saved cookie ({e})"));
            return None;
        }
    };
    let mut schema_hit = false;
    for url in CANDIDATES {
        match create(engine, &cookie, url).await {
            Mint::Key(secret) => return Some(secret),
            Mint::Missing => continue,
            Mint::Schema => {
                schema_hit = true;
                continue;
            }
            Mint::Dead(end) => {
                keyless_note(end);
                return None;
            }
        }
    }
    if schema_hit {
        keyless_note("key service refused every shape — hand-mint for now".to_owned());
    } else {
        keyless_note("key service answered 404 everywhere — hand-mint for now".to_owned());
    }
    None
}

enum Mint {
    Key(String),
    Missing,
    Schema,
    Dead(String),
}

// --> [`shapes`]
fn bodies() -> [Value; 5] {
    let scopes = json!([{
        "name": "asset",
        "operations": ["write"],
        "userIds": ["*"],
        "groupIds": ["*"],
    }]);
    let scopes_wide = json!([{
        "name": "asset",
        "operations": ["write"],
        "userIds": ["*"],
        "groupIds": ["*"],
        "universeIds": ["*"],
    }]);
    let scopes_bare = json!([{
        "name": "asset",
        "operations": ["write"],
    }]);
    [
        json!({ "name": "eclat-engine", "enabled": true, "scopes": scopes }),
        json!({ "displayName": "eclat-engine", "enabled": true, "scopes": scopes }),
        json!({ "name": "eclat-engine", "enabled": true, "scopes": scopes_bare }),
        json!({ "name": "eclat-engine", "enabled": true, "scopes": scopes_wide }),
        json!({ "name": "eclat-engine", "enabled": true, "allowedCidrs": ["0.0.0.0/0"], "scopes": scopes }),
    ]
}

// --> [`create`]
async fn create(engine: &Engine, cookie: &HeaderValue, url: &str) -> Mint {
    let bodies = bodies();
    for (index, body) in bodies.iter().enumerate() {
        match post_once(engine, cookie, url, body).await {
            Posted::Key(secret) => return Mint::Key(secret),
            Posted::Missing => return Mint::Missing,
            Posted::Schema(detail) => {
                banner::warn(format!("key mint {url} shape{} → {detail}", index + 1));
            }
            Posted::Dead(end) => return Mint::Dead(end),
        }
    }
    Mint::Schema
}

enum Posted {
    Key(String),
    Missing,
    Schema(String),
    Dead(String),
}

async fn post_once(engine: &Engine, cookie: &HeaderValue, url: &str, body: &Value) -> Posted {
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
            Err(e) => return Posted::Dead(format!("key service unreachable ({e})")),
        };
        let status = res.status();
        let text = res.text().await.unwrap_or_default();
        if status.is_success() {
            return match sniff_secret(&text) {
                Some(secret) => {
                    match tokio::fs::write(KEY_FILE, format!("{secret}\n")).await {
                        Ok(_) => banner::ok("opencloud key minted + saved to api_key.txt"),
                        Err(e) => banner::warn(format!("key minted but {KEY_FILE} would not save: {e}")),
                    }
                    Posted::Key(secret)
                }
                None => Posted::Dead(format!(
                    "mint answered {status} with no readable secret: {}",
                    snippet(&text)
                )),
            };
        }
        if status == StatusCode::NOT_FOUND || status == StatusCode::METHOD_NOT_ALLOWED {
            banner::warn(format!("key mint {url} → {status} {}", snippet(&text)));
            return Posted::Missing;
        }
        if status == StatusCode::FORBIDDEN && text.contains("Token Validation Failed") && attempt == 0 {
            let _ = engine.csrf.refresh().await;
            continue;
        }
        if status == StatusCode::BAD_REQUEST || status == StatusCode::UNPROCESSABLE_ENTITY {
            return Posted::Schema(format!("{status} {}", snippet(&text)));
        }
        if status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN {
            return Posted::Dead(format!("roblox refused the mint ({status}): {}", snippet(&text)));
        }
        return Posted::Dead(format!("key mint {url} → {status} {}", snippet(&text)));
    }
    Posted::Dead("mint unanswered".to_owned())
}
