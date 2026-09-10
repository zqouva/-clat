
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicU8, Ordering};
use std::sync::Arc;
use std::time::Duration;

use reqwest::header::HeaderValue;
use tokio::sync::{Notify, OnceCell, RwLock};

use crate::atelier::auth::{self, UserInfo};
use crate::atelier::banner;
use crate::atelier::csrf::CsrfCache;
use crate::atelier::limiter::Limiter;
use crate::atelier::queue::{JobBoard, Phase, ResponseQueue};
use crate::atelier::stash::Stash;

// --> [`measures`]
pub const STUDIO_UA: &str = "RobloxStudio/WinInet";
pub const POOL_TRACKS: usize = 32;
const COOKIE_FILE: &str = "cookie.txt";
const API_KEY_FILE: &str = "api_key.txt";

// --> [`jar`]
#[derive(Clone)]
pub struct CookieJar {
    inner: Arc<RwLock<String>>,
}

impl CookieJar {
    pub fn new(cookie: String) -> Self {
        Self { inner: Arc::new(RwLock::new(cookie)) }
    }

    pub async fn get(&self) -> String {
        self.inner.read().await.clone()
    }

    pub async fn set(&self, cookie: String) {
        *self.inner.write().await = cookie;
    }

    pub async fn header(&self) -> Result<HeaderValue, String> {
        auth::cookie_header(&self.get().await)
    }
}

// --> [`engine`]
pub struct Engine {
    pub http: reqwest::Client,
    pub cookie: CookieJar,
    pub user: RwLock<Option<UserInfo>>,
    pub csrf: CsrfCache,
    pub limiter: Limiter,
    pub queue: ResponseQueue,
    pub jobs: JobBoard,
    pub cookie_bell: Notify,
    pub cookie_seq: AtomicU64,
    pub opencloud_key: RwLock<Option<String>>,
    pub primary_dead: [AtomicBool; 3],
    pub key_seed: OnceCell<Option<String>>,
    pub shape_hint: [AtomicU8; 3],
    pub stash: Stash,
    pub mime_hint: [AtomicU8; 3],
    pub mime_shown: [AtomicU8; 3],
}

impl Engine {
    // --> [`pool`]
    fn pool() -> Result<reqwest::Client, String> {
        reqwest::Client::builder()
            .user_agent(STUDIO_UA)
            .pool_max_idle_per_host(POOL_TRACKS)
            .pool_idle_timeout(Duration::from_secs(90))
            .tcp_keepalive(Duration::from_secs(30))
            .http2_adaptive_window(true)
            .connect_timeout(Duration::from_secs(10))
            .timeout(Duration::from_secs(60))
            .build()
            .map_err(|e| format!("[éclat/client] cannot build the pool: {e}"))
    }

    // --> [`boot`]
    pub async fn boot(raw_cookie: String) -> Result<Arc<Self>, String> {
        let cookie = auth::sanitize(&raw_cookie);
        if cookie.is_empty() {
            return Err("[éclat/auth] cookie is empty".to_owned());
        }

        let http = Self::pool()?;
        banner::stage("pool", "32 connections · http/2 · keepalive");

        banner::stage("auth", "checking cookie...");
        let user = auth::validate(&http, &cookie).await?;
        banner::stage("auth", format!("logged in as {} (@{})", user.display_name, user.name));

        let jar = CookieJar::new(cookie);
        let csrf = CsrfCache::new(http.clone(), jar.clone());
        match csrf.warm().await {
            Ok(_) => banner::stage("csrf", "csrf ready"),
            Err(e) => banner::warn(format!("csrf warmup failed ({e}), will refresh on demand")),
        }

        let stash = Stash::load().await;
        let (saved_infos, saved_places, saved_universes) = stash.stats().await;
        let saved = saved_infos + saved_places + saved_universes;
        if saved > 0 {
            banner::stage("list", format!("{saved} saved · mode {}", stash.mode().await.as_str()));
        }

        let engine = Arc::new(Self {
            http,
            cookie: jar,
            user: RwLock::new(Some(user)),
            csrf,
            limiter: Limiter::new(),
            queue: ResponseQueue::new(),
            jobs: JobBoard::new(),
            cookie_bell: Notify::new(),
            cookie_seq: AtomicU64::new(1),
            opencloud_key: RwLock::new(None),
            primary_dead: [AtomicBool::new(false), AtomicBool::new(false), AtomicBool::new(false)],
            key_seed: OnceCell::new(),
            shape_hint: [AtomicU8::new(0), AtomicU8::new(0), AtomicU8::new(0)],
            stash,
            mime_hint: [AtomicU8::new(0), AtomicU8::new(0), AtomicU8::new(0)],
            mime_shown: [AtomicU8::new(0), AtomicU8::new(0), AtomicU8::new(0)],
        });
        let saved_key = load_opencloud_key().await;
        let key = crate::atelier::keysmith::ensure(&engine, saved_key).await;
        *engine.opencloud_key.write().await = key;
        Ok(engine)
    }

    pub async fn user(&self) -> Option<UserInfo> {
        self.user.read().await.clone()
    }

    pub fn primary_dead(&self, kind: crate::atelier::uploader::UploadKind) -> bool {
        self.primary_dead[kind.idx()].load(Ordering::Relaxed)
    }

    pub fn mark_primary_dead(&self, kind: crate::atelier::uploader::UploadKind) -> bool {
        !self.primary_dead[kind.idx()].swap(true, Ordering::Relaxed)
    }

    // --> [`key`]
    pub async fn opencloud_key(&self) -> Option<String> {
        if let Some(key) = self.opencloud_key.read().await.clone() {
            return Some(key);
        }
        let minted = self
            .key_seed
            .get_or_init(|| crate::atelier::keysmith::provision(self, "no key saved"))
            .await
            .clone();
        if minted.is_some() {
            *self.opencloud_key.write().await = minted.clone();
            return minted;
        }
        if let Some(key) = load_opencloud_key().await {
            *self.opencloud_key.write().await = Some(key.clone());
            return Some(key);
        }
        None
    }

    pub fn shape_hint(&self, kind: crate::atelier::uploader::UploadKind) -> u8 {
        self.shape_hint[kind.idx()].load(Ordering::Relaxed)
    }

    pub fn set_shape_hint(&self, kind: crate::atelier::uploader::UploadKind, hint: u8) {
        self.shape_hint[kind.idx()].store(hint, Ordering::Relaxed);
    }

    pub fn mime_hint(&self, kind: crate::atelier::uploader::UploadKind) -> u8 {
        self.mime_hint[kind.idx()].load(Ordering::Relaxed)
    }

    pub fn set_mime_hint(&self, kind: crate::atelier::uploader::UploadKind, hint: u8) {
        self.mime_hint[kind.idx()].store(hint, Ordering::Relaxed);
    }

    pub fn mime_noted(&self, kind: crate::atelier::uploader::UploadKind, bit: u8) -> bool {
        self.mime_shown[kind.idx()].fetch_or(bit, Ordering::SeqCst) & bit != 0
    }

    // --> [`import`]
    pub async fn set_cookie(&self, raw: &str) -> Result<UserInfo, String> {
        let cookie = auth::sanitize(raw);
        if cookie.is_empty() {
            return Err("[éclat/auth] imported cookie is empty".to_owned());
        }
        let user = auth::validate(&self.http, &cookie).await?;
        self.cookie.set(cookie.clone()).await;
        *self.user.write().await = Some(user.clone());
        if let Err(e) = self.csrf.refresh().await {
            banner::warn(format!("csrf refresh after import failed: {e}"));
        }
        if let Err(e) = tokio::fs::write(COOKIE_FILE, format!("{cookie}\n")).await {
            banner::warn(format!("could not save {COOKIE_FILE}: {e}"));
        }
        self.cookie_seq.fetch_add(1, Ordering::SeqCst);
        self.cookie_bell.notify_waiters();
        Ok(user)
    }

    // --> [`wait`]
    pub async fn await_fresh_cookie(&self, why: &str) {
        banner::warn(format!(
            "{why} — paused. import a fresh cookie (POST /cookie) to continue."
        ));
        self.jobs.set(Phase::AwaitingCookie).await;
        let generation = self.cookie_seq.load(Ordering::SeqCst);
        loop {
            match tokio::time::timeout(Duration::from_secs(30), self.cookie_bell.notified()).await {
                Ok(()) => {
                    if self.cookie_seq.load(Ordering::SeqCst) != generation {
                        break;
                    }
                }
                Err(_) => {
                    if self.cookie_seq.load(Ordering::SeqCst) != generation {
                        break;
                    }
                    banner::warn("still waiting for a fresh cookie (POST /cookie)...");
                }
            }
        }
        self.jobs.set(Phase::Running).await;
        banner::ok("fresh cookie imported, continuing");
    }
}

// --> [`opencloud key`]
async fn load_opencloud_key() -> Option<String> {
    if let Ok(key) = std::env::var("ECLAT_API_KEY") {
        let key = key.trim().to_owned();
        if !key.is_empty() {
            return Some(key);
        }
    }
    if let Ok(raw) = tokio::fs::read_to_string(API_KEY_FILE).await {
        for line in raw.lines() {
            let text = line.trim();
            if text.is_empty() || text.starts_with('#') {
                continue;
            }
            return Some(text.to_owned());
        }
    }
    None
}
