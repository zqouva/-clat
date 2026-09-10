
use std::time::{Duration, Instant};

use tokio::sync::{Mutex, OwnedSemaphorePermit, Semaphore};

use crate::atelier::retry;

pub const TRACKS: usize = 32;
pub const MINUTE_BUDGET: u32 = 3000;

struct Budget {
    opened: Instant,
    spent: u32,
}

pub struct Limiter {
    tracks: std::sync::Arc<Semaphore>,
    budget: Mutex<Budget>,
    cooldown_until: Mutex<Option<Instant>>,
}

impl Limiter {
    pub fn new() -> Self {
        Self {
            tracks: std::sync::Arc::new(Semaphore::new(TRACKS)),
            budget: Mutex::new(Budget { opened: Instant::now(), spent: 0 }),
            cooldown_until: Mutex::new(None),
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

    // --> [`refund`]
    pub async fn refund(&self) {
        if let Ok(mut view) = self.budget.try_lock() {
            view.spent = view.spent.saturating_sub(1);
        }
    }
}

impl Default for Limiter {
    fn default() -> Self {
        Self::new()
    }
}
