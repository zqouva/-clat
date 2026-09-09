//! --> ["pipeline"]
//!
//! --> the generic carry-engine: one pilgrimage for animation, mesh and sound.
//! --> the old tongue kept three near-identical gospels; éclat keeps one.
//!
//! --> the stations: universe → seals → scrolls (parallel 50s) → filter → houses →
//! --> couriers → one-buffer downloads → bounded uploads → answers.
//! --> a tired cookie pauses the walk (vigil) instead of killing it.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use bytes::Bytes;
use serde::Deserialize;
use tokio::sync::Mutex;
use tokio::task::JoinSet;

use crate::atelier::banner;
use crate::atelier::catalog;
use crate::atelier::client::Engine;
use crate::atelier::delivery;
use crate::atelier::queue::{Phase, ResponseItem};
use crate::atelier::retry;
use crate::atelier::uploader::{self, UploadFault, UploadKind};

pub const CHUNK: usize = 50;

// --> ["petition"]
// --> the studio's psalm, in its own tongue (camelCase, exactly as sent).
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RawRequest {
    #[serde(default)]
    pub place_id: i64,
    #[serde(default)]
    pub creator_id: i64,
    #[serde(default)]
    pub ids: Vec<i64>,
    #[serde(default)]
    pub default_place_ids: Vec<i64>,
    #[serde(default)]
    pub plugin_version: String,
    #[serde(default)]
    pub asset_type: String,
    // --> deployed plugins send `exportJson`; the old server tag read `exportJSON`
    // --> (Go matched case-insensitively). grace accepts both.
    #[serde(default, alias = "exportJSON")]
    pub export_json: bool,
    #[serde(default)]
    pub is_group: bool,
}

#[derive(Debug, Clone)]
pub struct ResolvedRequest {
    pub universe_id: i64,
    pub place_id: i64,
    pub creator_id: i64,
    pub ids: Vec<i64>,
    pub default_place_ids: Vec<i64>,
    pub kind: UploadKind,
    pub is_group: bool,
}

// --> ["pilgrimage"]
pub async fn reupload(engine: Arc<Engine>, raw: RawRequest) -> Result<(), String> {
    let kind = UploadKind::from_asset_type(&raw.asset_type)
        .ok_or_else(|| format!("[éclat/pipeline] unknown assetType {:?}", raw.asset_type))?;
    if raw.ids.is_empty() {
        return Err("[éclat/pipeline] no ids to carry".to_owned());
    }

    // --> ["universe"]
    banner::stage("universe", "asking which sky this place lives under …");
    let universe = match catalog::universe_for_place(&engine, raw.place_id).await {
        Ok(u) => u,
        Err(e) if e.contains("UNAUTHORIZED") => {
            engine.await_fresh_cookie("cookie expired at the universe gate").await;
            catalog::universe_for_place(&engine, raw.place_id).await?
        }
        Err(e) => return Err(e),
    };

    // --> ["seals"]
    banner::stage("permissions", "reading the seals …");
    match catalog::can_edit_universe(&engine, raw.is_group, raw.creator_id, universe).await {
        Ok(()) => {}
        Err(e) if e.contains("UNAUTHORIZED") => {
            engine.await_fresh_cookie("cookie expired at the permission seal").await;
            catalog::can_edit_universe(&engine, raw.is_group, raw.creator_id, universe).await?;
        }
        Err(e) => return Err(e),
    }

    let req = ResolvedRequest {
        universe_id: universe,
        place_id: raw.place_id,
        creator_id: raw.creator_id,
        ids: raw.ids.clone(),
        default_place_ids: raw.default_place_ids.clone(),
        kind,
        is_group: raw.is_group,
    };
    let target_group = if req.is_group { Some(req.creator_id) } else { None };
    banner::stage("carry", format!("{} × {} · universe {universe}", req.ids.len(), kind.as_str()));

    // --> ["scrolls"]
    let infos = fetch_infos(&engine, &req.ids).await;

    // --> ["filter"]
    // --> only strangers are carried: the target's own, ROBLOX's own (1),
    // --> and (for user pilgrimages) the pilgrim's own stay home.
    let user_id = engine.user().await.map(|u| u.id).unwrap_or(0);
    let mut targets = Vec::new();
    for info in &infos {
        if info.type_id != kind.type_id() {
            continue;
        }
        let c = info.creator.target_id;
        if c == req.creator_id || c == 1 {
            continue;
        }
        if !req.is_group && c == user_id {
            continue;
        }
        targets.push(info.clone());
    }
    let home = infos.len().saturating_sub(targets.len());
    if home > 0 {
        engine.jobs.add_processed(home as u32);
    }
    banner::stage("filter", format!("{} souls to carry · {home} already home", targets.len()));
    if targets.is_empty() {
        engine.queue.finish_export().await;
        engine.jobs.set(Phase::Finishing).await;
        return Ok(());
    }

    // --> ["houses"]
    let mut groups: HashMap<(String, i64), Vec<catalog::AssetInfo>> = HashMap::new();
    for info in targets {
        groups.entry((info.creator.kind.clone(), info.creator.target_id)).or_default().push(info);
    }
    banner::stage("creators", format!("{} houses to visit", groups.len()));

    let cache: PlaceCache = Arc::new(Mutex::new(HashMap::new()));
    let mut set = JoinSet::new();
    for ((creator_kind, creator_id), assets) in groups {
        let engine = engine.clone();
        let cache = cache.clone();
        let defaults = req.default_place_ids.clone();
        set.spawn(async move {
            carry_creator(engine, kind, creator_kind, creator_id, assets, defaults, target_group, universe, cache).await;
        });
    }
    while let Some(joined) = set.join_next().await {
        if let Err(e) = joined {
            banner::err(format!("creator carrier stumbled: {e}"));
        }
    }

    engine.queue.finish_export().await;
    engine.jobs.set(Phase::Finishing).await;
    let snapshot = engine.jobs.snapshot(engine.queue.len().await).await;
    banner::ok(format!("pilgrimage complete — {}/{} carried home", snapshot.processed, snapshot.total));
    Ok(())
}

// --> ["scrolls"]
// --> asset info in parallel 50s; a tired cookie earns a vigil, not a grave.
async fn fetch_infos(engine: &Arc<Engine>, ids: &[i64]) -> Vec<catalog::AssetInfo> {
    let mut set = JoinSet::new();
    for slice in ids.chunks(CHUNK) {
        let engine = engine.clone();
        let chunk: Vec<i64> = slice.to_vec();
        set.spawn(async move {
            let mut vigils = 0u32;
            loop {
                match catalog::assets_info(&engine, &chunk).await {
                    Ok(infos) => return (chunk.len(), Some(infos)),
                    Err(e) if e.contains("UNAUTHORIZED") && vigils < 3 => {
                        vigils += 1;
                        engine.await_fresh_cookie("cookie expired while reading asset scrolls").await;
                    }
                    Err(e) => {
                        banner::err(format!("asset scrolls unreadable for {} ids: {e}", chunk.len()));
                        return (chunk.len(), None);
                    }
                }
            }
        });
    }
    let mut out = Vec::new();
    while let Some(joined) = set.join_next().await {
        match joined {
            Ok((_, Some(infos))) => out.extend(infos),
            Ok((len, None)) => {
                engine.jobs.add_processed(len as u32);
            }
            Err(e) => banner::err(format!("scroll carrier panicked: {e}")),
        }
    }
    out
}

type PlaceCache = Arc<Mutex<HashMap<(String, i64), Vec<i64>>>>;

// --> ["carry"]
// --> visit one creator's house: resolve locations place by place,
// --> then fan uploads out across the tracks (bounded, bursty).
#[allow(clippy::too_many_arguments)]
async fn carry_creator(
    engine: Arc<Engine>,
    kind: UploadKind,
    creator_kind: String,
    creator_id: i64,
    assets: Vec<catalog::AssetInfo>,
    defaults: Vec<i64>,
    group: Option<i64>,
    universe: i64,
    cache: PlaceCache,
) {
    let mut by_id: HashMap<i64, catalog::AssetInfo> = HashMap::new();
    for info in assets {
        by_id.insert(info.id, info);
    }
    let asset_count = by_id.len() as u32;
    let mut remaining: Vec<i64> = by_id.keys().copied().collect();

    let places = {
        let mut vigils = 0u32;
        loop {
            match creator_places(&engine, &creator_kind, creator_id, &defaults, &cache).await {
                Ok(places) => break places,
                Err(e) if e.contains("UNAUTHORIZED") && vigils < 3 => {
                    vigils += 1;
                    engine.await_fresh_cookie("cookie expired while reading the creator atlas").await;
                }
                Err(e) => {
                    banner::err(e);
                    engine.jobs.add_processed(asset_count);
                    return;
                }
            }
        }
    };

    let mut uploads = JoinSet::new();
    for place_id in places {
        if remaining.is_empty() {
            break;
        }
        // --> ["courier walk"]
        // --> a vigil re-walks the place with fresh eyes.
        let mut vigils = 0u32;
        let (still, resolved) = loop {
            let mut still: Vec<i64> = Vec::new();
            let mut resolved: Vec<(i64, String)> = Vec::new();
            let mut auth_wounded = false;
            for slice in remaining.chunks(CHUNK) {
                match delivery::batch(&engine, slice, place_id).await {
                    Err(e) => {
                        banner::err(format!("courier failed via place {place_id}: {e}"));
                        still.extend_from_slice(slice);
                    }
                    Ok(locs) => {
                        if locs.len() != slice.len() {
                            banner::warn(format!(
                                "courier answered {} locations for {} petitions — asking again later",
                                locs.len(),
                                slice.len()
                            ));
                            still.extend_from_slice(slice);
                            continue;
                        }
                        for (index, loc) in locs.iter().enumerate() {
                            let aid = slice[index];
                            if let Some(entry) = loc.locations.first() {
                                if entry.location.is_empty() {
                                    still.push(aid);
                                } else {
                                    resolved.push((aid, entry.location.clone()));
                                }
                            } else {
                                if loc.errors.first().map(|e| e.message.contains("Authentication required")).unwrap_or(false) {
                                    auth_wounded = true;
                                }
                                still.push(aid);
                            }
                        }
                    }
                }
            }
            if auth_wounded && vigils < 3 {
                vigils += 1;
                engine.await_fresh_cookie("cookie expired amid the courier's run").await;
                continue;
            }
            break (still, resolved);
        };

        if still.len() < remaining.len() {
            promote_place(&cache, (&creator_kind, creator_id), place_id).await;
        }
        for (aid, url) in resolved {
            if let Some(info) = by_id.remove(&aid) {
                let eng = engine.clone();
                uploads.spawn(async move {
                    let total = eng.jobs.total();
                    match upload_one(&eng, kind, &info, &url, group).await {
                        Ok(new_id) => {
                            let current = eng.jobs.add_processed(1);
                            eng.queue.add(ResponseItem { old_id: info.id, new_id }).await;
                            banner::carried(current, total, &info.name, info.id, new_id);
                            if kind == UploadKind::Audio {
                                if let Err(e) = uploader::grant_universe_use(&eng, new_id, universe).await {
                                    banner::warn(format!("sound {new_id} carried, but the blessing failed: {e}"));
                                }
                            }
                        }
                        Err(e) => {
                            eng.jobs.add_processed(1);
                            banner::err(format!("{} ({}) could not be carried: {e}", info.name, info.id));
                        }
                    }
                });
            }
        }
        remaining = still;
    }

    for aid in remaining {
        banner::err(format!("no courier knew asset {aid} — left behind"));
        engine.jobs.add_processed(1);
    }
    while uploads.join_next().await.is_some() {}
}

// --> ["atlas"]
async fn creator_places(
    engine: &Engine,
    creator_kind: &str,
    creator_id: i64,
    defaults: &[i64],
    cache: &PlaceCache,
) -> Result<Vec<i64>, String> {
    let key = (creator_kind.to_owned(), creator_id);
    if let Some(places) = cache.lock().await.get(&key).cloned() {
        return Ok(places);
    }
    let atlas = if creator_kind == "Group" {
        catalog::group_games(engine, creator_id).await?
    } else {
        catalog::user_games(engine, creator_id).await?
    };
    let mut places: Vec<i64> = atlas
        .data
        .into_iter()
        .map(|game| game.root_place.id)
        .filter(|id| *id > 0 && !defaults.contains(id))
        .collect();
    places.extend_from_slice(defaults);
    if places.is_empty() {
        return Err(format!("[éclat/pipeline] creator {creator_kind} {creator_id} has no reachable places"));
    }
    cache.lock().await.insert(key, places.clone());
    Ok(places)
}

// --> ["promote"]
// --> the generous place is remembered first next time.
async fn promote_place(cache: &PlaceCache, creator: (&str, i64), place_id: i64) {
    let mut guard = cache.lock().await;
    if let Some(places) = guard.get_mut(&(creator.0.to_owned(), creator.1)) {
        if let Some(pos) = places.iter().position(|&p| p == place_id) {
            let id = places.remove(pos);
            places.insert(0, id);
        }
    }
}

// --> ["one"]
// --> download once into a single buffer, then carry with classified retries.
async fn upload_one(
    engine: &Engine,
    kind: UploadKind,
    info: &catalog::AssetInfo,
    url: &str,
    group: Option<i64>,
) -> Result<i64, String> {
    let data = delivery::download(engine, url).await?;
    upload_with_data(engine, kind, &info.name, &info.description, info.id, data, group).await
}

/// --> the direct verse: studio streams bytes (hex) and we carry them home.
pub async fn upload_direct(
    engine: &Engine,
    kind: UploadKind,
    name: String,
    description: String,
    data: Bytes,
    group: Option<i64>,
) -> Result<i64, String> {
    upload_with_data(engine, kind, &name, &description, 0, data, group).await
}

async fn upload_with_data(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    old_id: i64,
    data: Bytes,
    group: Option<i64>,
) -> Result<i64, String> {
    let mut name = if name.trim().is_empty() {
        format!("{}-{old_id}", kind.as_str())
    } else {
        name.to_owned()
    };
    let mut vigils = 0u32;
    let mut attempt = 0u32;
    loop {
        attempt += 1;
        let user_id = engine.user().await.map(|u| u.id).unwrap_or(0);
        match uploader::upload_once(engine, kind, &name, description, data.clone(), group, user_id).await {
            Ok(id) => return Ok(id),
            Err(e) => match e.fault {
                UploadFault::TokenStale => {
                    if attempt >= 4 {
                        return Err(e.message);
                    }
                    engine
                        .csrf
                        .refresh()
                        .await
                        .map_err(|round| format!("{} (csrf refresh failed: {round})", e.message))?;
                    tokio::time::sleep(retry::jitter(Duration::from_millis(300))).await;
                }
                UploadFault::NameModerated => {
                    if name == "[Censored]" || attempt >= 3 {
                        return Err(e.message);
                    }
                    name = "[Censored]".to_owned();
                }
                UploadFault::RateLimited(after) => {
                    if attempt >= 6 {
                        return Err(e.message);
                    }
                    engine.limiter.note_429(after).await;
                    tokio::time::sleep(after.unwrap_or(Duration::from_secs(2)) + retry::jitter(Duration::from_millis(400))).await;
                }
                UploadFault::Reauth(why) => {
                    vigils += 1;
                    if vigils > 4 {
                        return Err(format!("{why} (too many vigils)"));
                    }
                    engine.await_fresh_cookie(&why).await;
                }
                UploadFault::LegacyGone => return Err(e.message),
                UploadFault::Fatal(_) => return Err(e.message),
            },
        }
    }
}
