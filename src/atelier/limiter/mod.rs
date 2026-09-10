
use std::time::{Duration, Instant};

use tokio::sync::{Mutex, OwnedSemaphorePermit, Semaphore};

use crate::atelier::retry;

pub const TRACKS: usize = 32;
pub const MINUTE_BUDGET: u32 = 3000;
pub const UPLOAD_TRACKS: usize = 64;
pub const UPLOAD_MINUTE_BUDGET: u32 = 5000;
pub const AUDIO_MINUTE_BUDGET: u32 = 120;
pub const GRANT_MINUTE_BUDGET: u32 = 60;

struct Budget {
    opened: Instant,
    spent: u32,
}

pub struct Limiter {
    tracks: std::sync::Arc<Semaphore>,
    budget: Mutex<Budget>,
    cooldown_until: Mutex<Option<Instant>>,
    up_cool: Mutex<Option<Instant>>,
    upload_slots: std::sync::Arc<Semaphore>,
    upload_budget: Mutex<Budget>,
    audio_budget: Mutex<Budget>,
    grant_budget: Mutex<Budget>,
}

impl Limiter {
    pub fn new() -> Self {
        Self {
            tracks: std::sync::Arc::new(Semaphore::new(TRACKS)),
            budget: Mutex::new(Budget { opened: Instant::now(), spent: 0 }),
            cooldown_until: Mutex::new(None),
            up_cool: Mutex::new(None),
            upload_slots: std::sync::Arc::new(Semaphore::new(UPLOAD_TRACKS)),
            upload_budget: Mutex::new(Budget { opened: Instant::now(), spent: 0 }),
            audio_budget: Mutex::new(Budget { opened: Instant::now(), spent: 0 }),
            grant_budget: Mutex::new(Budget { opened: Instant::now(), spent: 0 }),
        }
    }

    // --> [`track`]
    pub async fn track(&self) -> OwnedSemaphorePermit {
        self.tracks
            .clone()
            .acquire_owned()
            .await
            .expect("[éclat/limiter] semaphore closed")
    }

    // --> [`budget`]
    pub async fn api_budget(&self) {
        loop {
            // --> [`cooldown`]
            let cool_down = {
                let mut guard = self.cooldown_until.lock().await;
                match *guard {
                    Some(until) if Instant::now() < until => Some(until - Instant::now()),
                    _ => {
                        *guard = None;
                        None
                    }
                }
            };
            if let Some(wait) = cool_down {
                tokio::time::sleep(wait).await;
                continue;
            }

            // --> [`window`]
            let reset_in = {
                let mut view = self.budget.lock().await;
                let now = Instant::now();
                if now.duration_since(view.opened) >= Duration::from_secs(60) {
                    view.opened = now;
                    view.spent = 0;
                }
                if view.spent < MINUTE_BUDGET {
                    view.spent += 1;
                    None
                } else {
                    Some((view.opened + Duration::from_secs(60)).saturating_duration_since(now))
                }
            };
            match reset_in {
                None => return,
                Some(wait) => {
                    tokio::time::sleep(wait + retry::jitter(Duration::from_millis(120))).await;
                }
            }
        }
    }

    // --> [`429`]
    pub async fn note_429(&self, after: Option<Duration>) {
        let wait = after.unwrap_or(Duration::from_secs(5)) + retry::jitter(Duration::from_millis(500));
        let mut guard = self.cooldown_until.lock().await;
        let until = Instant::now() + wait;
        *guard = Some(guard.map(|old| old.max(until)).unwrap_or(until));
    }

    pub async fn note_429_upload(&self, after: Option<Duration>) {
        let wait = after.unwrap_or(Duration::from_secs(5)) + retry::jitter(Duration::from_millis(500));
        let mut guard = self.up_cool.lock().await;
        let until = Instant::now() + wait;
        *guard = Some(guard.map(|old| old.max(until)).unwrap_or(until));
    }

    // --> [`refund`]
    pub async fn refund(&self) {
        if let Ok(mut view) = self.budget.try_lock() {
            view.spent = view.spent.saturating_sub(1);
        }
    }

    // --> [`upload`]
    pub async fn upload_slot(&self) -> OwnedSemaphorePermit {
        self.upload_slots
            .clone()
            .acquire_owned()
            .await
            .expect("[éclat/limiter] semaphore closed")
    }

    pub async fn upload_budget(&self) {
        loop {
            let cool_down = {
                let mut guard = self.up_cool.lock().await;
                match *guard {
                    Some(until) if Instant::now() < until => Some(until - Instant::now()),
                    _ => {
                        *guard = None;
                        None
                    }
                }
            };
            if let Some(wait) = cool_down {
                tokio::time::sleep(wait).await;
                continue;
            }

            let reset_in = {
                let mut view = self.upload_budget.lock().await;
                let now = Instant::now();
                if now.duration_since(view.opened) >= Duration::from_secs(60) {
                    view.opened = now;
                    view.spent = 0;
                }
                if view.spent < UPLOAD_MINUTE_BUDGET {
                    view.spent += 1;
                    None
                } else {
                    Some((view.opened + Duration::from_secs(60)).saturating_duration_since(now))
                }
            };
            match reset_in {
                None => return,
                Some(wait) => {
                    tokio::time::sleep(wait + retry::jitter(Duration::from_millis(120))).await;
                }
            }
        }
    }

    pub async fn refund_upload(&self) {
        if let Ok(mut view) = self.upload_budget.try_lock() {
            view.spent = view.spent.saturating_sub(1);
        }
    }

    // --> [`audio`]
    pub async fn audio_budget(&self) {
        loop {
            let cool_down = {
                let mut guard = self.up_cool.lock().await;
                match *guard {
                    Some(until) if Instant::now() < until => Some(until - Instant::now()),
                    _ => {
                        *guard = None;
                        None
                    }
                }
            };
            if let Some(wait) = cool_down {
                tokio::time::sleep(wait).await;
                continue;
            }

            let reset_in = {
                let mut view = self.audio_budget.lock().await;
                let now = Instant::now();
                if now.duration_since(view.opened) >= Duration::from_secs(60) {
                    view.opened = now;
                    view.spent = 0;
                }
                if view.spent < AUDIO_MINUTE_BUDGET {
                    view.spent += 1;
                    None
                } else {
                    Some((view.opened + Duration::from_secs(60)).saturating_duration_since(now))
                }
            };
            match reset_in {
                None => return,
                Some(wait) => {
                    tokio::time::sleep(wait + retry::jitter(Duration::from_millis(120))).await;
                }
            }
        }
    }

    pub async fn refund_audio(&self) {
        if let Ok(mut view) = self.audio_budget.try_lock() {
            view.spent = view.spent.saturating_sub(1);
        }
    }

    // --> [`grant`]
    pub async fn grant_budget(&self) {
        loop {
            let cool_down = {
                let mut guard = self.cooldown_until.lock().await;
                match *guard {
                    Some(until) if Instant::now() < until => Some(until - Instant::now()),
                    _ => {
                        *guard = None;
                        None
                    }
                }
            };
            if let Some(wait) = cool_down {
                tokio::time::sleep(wait).await;
                continue;
            }

            let reset_in = {
                let mut view = self.grant_budget.lock().await;
                let now = Instant::now();
                if now.duration_since(view.opened) >= Duration::from_secs(60) {
                    view.opened = now;
                    view.spent = 0;
                }
                if view.spent < GRANT_MINUTE_BUDGET {
                    view.spent += 1;
                    None
                } else {
                    Some((view.opened + Duration::from_secs(60)).saturating_duration_since(now))
                }
            };
            match reset_in {
                None => return,
                Some(wait) => {
                    tokio::time::sleep(wait + retry::jitter(Duration::from_millis(120))).await;
                }
            }
        }
    }
}

impl Default for Limiter {
    fn default() -> Self {
        Self::new()
    }
}
