//! --> ["auth"]
//!
//! --> frictionless cookie ingestion.
//! --> the pilgrim pastes raw chaos; the engine returns a verified soul.
//! --> spaces, quotes and accidental prefixes are forgiven on sight.
//! --> the _|WARNING body is sacred — it is part of the token, never stripped.

use reqwest::header::{HeaderValue, COOKIE};
use serde::{Deserialize, Serialize};

/// --> ["marks"]
/// --> a lenient fingerprint: the full warning sentence opens with this.
/// --> its absence earns a warning, never a rejection — the handshake decides.
pub const WARNING_MARK: &str = "_|WARNING:-DO-NOT-SHARE-THIS.";

const AUTH_URL: &str = "https://users.roblox.com/v1/users/authenticated";

// --> ["soul"]
// --> who the cookie dreams it is, mapped into memory.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub id: i64,
    #[serde(default, alias = "username")]
    pub name: String,
    #[serde(default, rename = "displayName")]
    pub display_name: String,
}

// --> ["sanitize"]
// --> forgive the paste: trim, unquote, drop transport prefixes.
pub fn sanitize(raw: &str) -> String {
    let mut out = raw.trim().to_owned();

    // --> ["unquote"]
    if out.len() >= 2 {
        let bytes = out.as_bytes();
        let (first, last) = (bytes[0], bytes[out.len() - 1]);
        if (first == b'"' && last == b'"') || (first == b'\'' && last == b'\'') {
            out = out[1..out.len() - 1].trim().to_owned();
        }
    }

    // --> ["unprefix"]
    // --> meta-prefixes only. the _|WARNING body is never touched.
    const PREFIXES: [&str; 8] = [
        ".ROBLOSECURITY=",
        ".ROBLOSECURITY:",
        ".ROBLOSECURITY ",
        "ROBLOSECURITY=",
        "Cookie:",
        "cookie:",
        "Cookie=",
        "cookie=",
    ];
    loop {
        let mut cut = false;
        for prefix in PREFIXES {
            if let Some(rest) = out.strip_prefix(prefix) {
                out = rest.trim().to_owned();
                cut = true;
                break;
            }
        }
        if !cut {
            break;
        }
    }

    // --> ["unwrap pairs"]
    // --> some exporters hand us `name=value`; keep the value side.
    if let Some((name, value)) = out.split_once('=') {
        let name = name.trim();
        if name.eq_ignore_ascii_case(".ROBLOSECURITY") || name.eq_ignore_ascii_case("cookie") {
            out = value.trim().to_owned();
        }
    }

    out
}

// --> ["vessel"]
// --> the cookie, dressed for HTTP. invalid characters fail loud, never panic.
pub fn cookie_header(cookie: &str) -> Result<HeaderValue, String> {
    HeaderValue::from_str(&format!(".ROBLOSECURITY={cookie}"))
        .map_err(|_| "[éclat/auth] cookie holds characters illegal in HTTP headers".to_owned())
}

// --> ["handshake"]
// --> one knock on users.roblox.com; 200 maps the soul, 401 ends the dream.
pub async fn validate(http: &reqwest::Client, cookie: &str) -> Result<UserInfo, String> {
    if !cookie.contains(WARNING_MARK) {
        crate::atelier::banner::warn(
            "cookie lacks the _|WARNING body — continuing anyway; the handshake is the true judge.",
        );
    }
    let response = http
        .get(AUTH_URL)
        .header(COOKIE, cookie_header(cookie)?)
        .send()
        .await
        .map_err(|e| format!("[éclat/auth] the handshake could not reach roblox: {e}"))?;

    let status = response.status();
    if status == reqwest::StatusCode::OK {
        return response
            .json::<UserInfo>()
            .await
            .map_err(|e| format!("[éclat/auth] roblox spoke an unreadable soul: {e}"));
    }
    if status == reqwest::StatusCode::UNAUTHORIZED {
        return Err("[éclat/auth] invalid cookie (roblox answered 401) — paste a fresh .ROBLOSECURITY".to_owned());
    }
    let body = response.text().await.unwrap_or_default();
    Err(format!("[éclat/auth] handshake failed: {status} {body}"))
}
