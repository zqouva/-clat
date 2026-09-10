
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

    // --> [`read`]
    pub async fn get(&self) -> String {
        self.token.read().await.clone()
    }

    pub async fn header_value(&self) -> Result<HeaderValue, String> {
        HeaderValue::from_str(&self.get().await)
            .map_err(|_| "[éclat/csrf] token holds characters illegal in HTTP headers".to_owned())
    }

    // --> [`sip`]
    pub async fn observe(&self, headers: &HeaderMap) {
        if let Some(value) = headers.get(TOKEN_HEADER) {
            if let Ok(text) = value.to_str() {
                if !text.is_empty() && text != BOOTSTRAP_TOKEN {
                    *self.token.write().await = text.to_owned();
                }
            }
        }
    }

    // --> [`warm`]
    pub async fn warm(&self) -> Result<String, String> {
        if self.get().await.is_empty() {
            self.refresh().await
        } else {
            Ok(self.get().await)
        }
    }

    // --> [`refresh`]
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
            .map_err(|e| format!("[éclat/csrf] csrf refresh could not reach roblox: {e}"))?;

        if response.status() == reqwest::StatusCode::OK {
            return Err("[éclat/csrf] logout check returned 200, refusing to continue (session safety)".to_owned());
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
