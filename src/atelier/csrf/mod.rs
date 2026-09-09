//! --> ["csrf"]
//!
//! --> the single-flight token candle.
//! --> roblox guards every write with X-CSRF-Token; the engine keeps one
//! --> burning, refreshes it through exactly one pilgrim at a time,
//! --> and sips fresh tokens off every passing response for free.
//!
//! --> session safety: the refresh rite knocks on the logout altar
//! --> with a dummy token, so it can only ever receive 403 + a token.
//! --> a 200 there would mean a real logout — we refuse to continue.

use std::sync::Arc;

use reqwest::header::{HeaderMap, HeaderValue, COOKIE};
use tokio::sync::{Mutex, RwLock};

use crate::atelier::auth;
use crate::atelier::client::CookieJar;

const LOGOUT_URL: &str = "https://auth.roblox.com/v2/logout";
const BOOTSTRAP_TOKEN: &str = "eclat-bootstrap";
const TOKEN_HEADER: &str = "x-csrf-token";

#[derive(Clone)]
pub struct CsrfCache {
    http: reqwest::Client,
    cookie: CookieJar,
    token: Arc<RwLock<String>>,
    flight: Arc<Mutex<()>>,
}

impl CsrfCache {
    pub fn new(http: reqwest::Client, cookie: CookieJar) -> Self {
        Self {
            http,
            cookie,
            token: Arc::new(RwLock::new(String::new())),
            flight: Arc::new(Mutex::new(())),
        }
    }

    // --> ["read"]
    pub async fn get(&self) -> String {
        self.token.read().await.clone()
    }

    pub async fn header_value(&self) -> Result<HeaderValue, String> {
        HeaderValue::from_str(&self.get().await)
            .map_err(|_| "[éclat/csrf] token holds characters illegal in HTTP headers".to_owned())
    }

    // --> ["sip"]
    // --> opportunistic refresh: any response carrying a token renews the candle.
    pub async fn observe(&self, headers: &HeaderMap) {
        if let Some(value) = headers.get(TOKEN_HEADER) {
            if let Ok(text) = value.to_str() {
                if !text.is_empty() && text != BOOTSTRAP_TOKEN {
                    *self.token.write().await = text.to_owned();
                }
            }
        }
    }

    // --> ["warm"]
    pub async fn warm(&self) -> Result<String, String> {
        if self.get().await.is_empty() {
            self.refresh().await
        } else {
            Ok(self.get().await)
        }
    }

    // --> ["refresh"]
    // --> single-flight: thirty-two tracks may thirst, one pilgrim fetches.
    pub async fn refresh(&self) -> Result<String, String> {
        let _guard = self.flight.lock().await;

        let cookie = self.cookie.get().await;
        let response = self
            .http
            .post(LOGOUT_URL)
            .header(COOKIE, auth::cookie_header(&cookie)?)
            .header(TOKEN_HEADER, BOOTSTRAP_TOKEN)
            .body(String::new())
            .send()
            .await
            .map_err(|e| format!("[éclat/csrf] the token rite could not reach roblox: {e}"))?;

        if response.status() == reqwest::StatusCode::OK {
            return Err("[éclat/csrf] logout rite returned 200 — refusing to continue (session safety)".to_owned());
        }
        match response.headers().get(TOKEN_HEADER) {
            Some(value) => {
                let token = value
                    .to_str()
                    .map_err(|_| "[éclat/csrf] roblox minted an unprintable token".to_owned())?
                    .to_owned();
                if token.is_empty() {
                    return Err("[éclat/csrf] roblox minted an empty token".to_owned());
                }
                *self.token.write().await = token.clone();
                Ok(token)
            }
            None => Err(format!(
                "[éclat/csrf] no {TOKEN_HEADER} arrived ({})",
                response.status()
            )),
        }
    }
}
