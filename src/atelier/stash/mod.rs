use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::atelier::catalog::AssetInfo;

const LIST_FILE: &str = "eclat_cache.json";
const HOUR: u64 = 3600;
const DAY: u64 = 86400;

// --> [`mode`]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum StashMode {
    Fresh,
    Hour,
    Day,
    Keep,
}

impl StashMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            StashMode::Fresh => "fresh",
            StashMode::Hour => "hour",
            StashMode::Day => "day",
            StashMode::Keep => "keep",
        }
    }

    fn fresh(&self, at: u64, now: u64) -> bool {
        match self {
            StashMode::Fresh => false,
            StashMode::Hour => now.saturating_sub(at) < HOUR,
            StashMode::Day => now.saturating_sub(at) < DAY,
            StashMode::Keep => true,
        }
    }
}

impl Default for StashMode {
    fn default() -> Self {
        StashMode::Hour
    }
}

// --> [`entry`]
#[derive(Debug, Clone, Serialize, Deserialize)]
struct Entry<T> {
    at: u64,
    val: T,
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct Inner {
    #[serde(default)]
    mode: StashMode,
    #[serde(default)]
    infos: HashMap<i64, Entry<AssetInfo>>,
    #[serde(default)]
    places: HashMap<String, Entry<Vec<i64>>>,
    #[serde(default)]
    universes: HashMap<i64, Entry<i64>>,
}

// --> [`stash`]
pub struct Stash {
    inner: RwLock<Inner>,
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

impl Stash {
    pub async fn load() -> Self {
        let inner = match tokio::fs::read_to_string(LIST_FILE).await {
            Ok(text) => serde_json::from_str::<Inner>(&text).unwrap_or_default(),
            Err(_) => Inner::default(),
        };
        Self { inner: RwLock::new(inner) }
    }

    pub async fn mode(&self) -> StashMode {
        self.inner.read().await.mode
    }

    pub async fn set_mode(&self, mode: StashMode) {
        let mut guard = self.inner.write().await;
        guard.mode = mode;
        save_locked(&guard).await;
    }

    pub async fn clear(&self) -> usize {
        let mut guard = self.inner.write().await;
        let n = guard.infos.len() + guard.places.len() + guard.universes.len();
        guard.infos.clear();
        guard.places.clear();
        guard.universes.clear();
        save_locked(&guard).await;
        n
    }

    pub async fn stats(&self) -> (usize, usize, usize) {
        let guard = self.inner.read().await;
        (guard.infos.len(), guard.places.len(), guard.universes.len())
    }

    // --> [`infos`]
    pub async fn split_infos(&self, ids: &[i64]) -> (Vec<AssetInfo>, Vec<i64>) {
        let guard = self.inner.read().await;
        let stamp = now();
        let mut hits = Vec::new();
        let mut missing = Vec::new();
        for id in ids {
            match guard.infos.get(id) {
                Some(entry) if guard.mode.fresh(entry.at, stamp) => hits.push(entry.val.clone()),
                _ => missing.push(*id),
            }
        }
        (hits, missing)
    }

    pub async fn put_infos(&self, infos: Vec<AssetInfo>) {
        if infos.is_empty() {
            return;
        }
        let mut guard = self.inner.write().await;
        let stamp = now();
        for info in infos {
            guard.infos.insert(info.id, Entry { at: stamp, val: info });
        }
        save_locked(&guard).await;
    }

    // --> [`places`]
    fn place_key(kind: &str, id: i64) -> String {
        format!("{kind}:{id}")
    }

    pub async fn get_places(&self, kind: &str, id: i64) -> Option<Vec<i64>> {
        let guard = self.inner.read().await;
        let entry = guard.places.get(&Self::place_key(kind, id))?;
        if guard.mode.fresh(entry.at, now()) {
            Some(entry.val.clone())
        } else {
            None
        }
    }

    pub async fn put_places(&self, kind: &str, id: i64, places: Vec<i64>) {
        let mut guard = self.inner.write().await;
        guard
            .places
            .insert(Self::place_key(kind, id), Entry { at: now(), val: places });
        save_locked(&guard).await;
    }

    // --> [`universe`]
    pub async fn get_universe(&self, place_id: i64) -> Option<i64> {
        let guard = self.inner.read().await;
        let entry = guard.universes.get(&place_id)?;
        if guard.mode.fresh(entry.at, now()) {
            Some(entry.val)
        } else {
            None
        }
    }

    pub async fn put_universe(&self, place_id: i64, universe: i64) {
        let mut guard = self.inner.write().await;
        guard.universes.insert(place_id, Entry { at: now(), val: universe });
        save_locked(&guard).await;
    }
}

async fn save_locked(inner: &Inner) {
    match serde_json::to_string(inner) {
        Ok(text) => {
            let _ = tokio::fs::write(LIST_FILE, text).await;
        }
        Err(_) => {}
    }
}
