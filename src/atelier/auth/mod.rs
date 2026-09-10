
use reqwest::header::{HeaderValue, COOKIE};
use serde::{Deserialize, Serialize};

pub const WARNING_MARK: &str = "_|WARNING:-DO-NOT-SHARE-THIS.";

const AUTH_URL: &str = "https://users.roblox.com/v1/users/authenticated";

// --> [`user`]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserInfo {
    pub id: i64,
    #[serde(default, alias = "username")]
    pub name: String,
    #[serde(default, rename = "displayName")]
    pub display_name: String,
}

// --> [`sanitize`]
pub fn sanitize(raw: &str) -> String {
    let mut out = raw.trim().to_owned();

    // --> [`unquote`]
    if out.len() >= 2 {
        let bytes = out.as_bytes();
        let (first, last) = (bytes[0], bytes[out.len() - 1]);
        if (first == b'"' && last == b'"') || (first == b'\'' && last == b'\'') {
            out = out[1..out.len() - 1].trim().to_owned();
        }
    }

    // --> [`unprefix`]
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

    // --> [`unwrap pairs`]
    if let Some((name, value)) = out.split_once('=') {
        let name = name.trim();
        if name.eq_ignore_ascii_case(".ROBLOSECURITY") || name.eq_ignore_ascii_case("cookie") {
            out = value.trim().to_owned();
        }
    }

    out
}

// --> [`header`]
pub fn cookie_header(cookie: &str) -> Result<HeaderValue, String> {
    HeaderValue::from_str(&format!(".ROBLOSECURITY={cookie}"))
        .map_err(|_| "[éclat/auth] cookie holds characters illegal in HTTP headers".to_owned())
}

// --> [`handshake`]
pub async fn validate(http: &reqwest::Client, cookie: &str) -> Result<UserInfo, String> {
    if !cookie.contains(WARNING_MARK) {
        crate::atelier::banner::warn(
            "cookie is missing the _|WARNING marker. continuing anyway.",
        );
    }
    let response = http
        .get(AUTH_URL)
        .header(COOKIE, cookie_header(cookie)?)
        .send()
        .await
        .map_err(|e| format!("[éclat/auth] could not reach roblox: {e}"))?;

    let status = response.status();
    if status == reqwest::StatusCode::OK {
        return response
            .json::<UserInfo>()
            .await
            .map_err(|e| format!("[éclat/auth] roblox returned bad user json: {e}"));
    }
    if status == reqwest::StatusCode::UNAUTHORIZED {
        return Err("[éclat/auth] invalid cookie (roblox answered 401) — paste a fresh .ROBLOSECURITY".to_owned());
    }
    let body = response.text().await.unwrap_or_default();
    Err(format!("[éclat/auth] auth check failed: {status} {body}"))
}
