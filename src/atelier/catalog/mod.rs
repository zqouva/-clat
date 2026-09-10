
use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde::Deserialize;
use std::time::Duration;

use crate::atelier::client::Engine;
use crate::atelier::retry::{self, Retryable};

// --> [`assets`]
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreatorRef {
    #[serde(default, rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub type_id: i32,
    #[serde(default)]
    pub target_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetInfo {
    #[serde(default)]
    pub id: i64,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default, rename = "type")]
    pub kind: String,
    #[serde(default)]
    pub type_id: i32,
    #[serde(default)]
    pub creator: CreatorRef,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct ApiError {
    #[serde(default)]
    pub code: i64,
    #[serde(default)]
    pub message: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct AssetsInfoResponse {
    #[serde(default)]
    pub data: Vec<AssetInfo>,
    #[serde(default)]
    pub errors: Vec<ApiError>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaceDetails {
    #[serde(default)]
    pub place_id: i64,
    #[serde(default)]
    pub universe_id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GamesResponse {
    #[serde(default)]
    pub data: Vec<GameEntry>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GameEntry {
    #[serde(default)]
    pub root_place: RootPlace,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RootPlace {
    #[serde(default)]
    pub id: i64,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Membership {
    #[serde(default)]
    pub user_role: MembershipRole,
    #[serde(default)]
    pub permissions: MembershipPermissions,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MembershipRole {
    #[serde(default)]
    pub role: RoleName,
}

#[derive(Debug, Clone, Default, Deserialize)]
pub struct RoleName {
    #[serde(default)]
    pub name: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MembershipPermissions {
    #[serde(default)]
    pub group_economy_permissions: EconomyPermissions,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EconomyPermissions {
    #[serde(default)]
    pub create_items: bool,
    #[serde(default)]
    pub manage_group_games: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TeamCreate {
    #[serde(default)]
    pub is_enabled: bool,
}

// --> [`get`]
async fn api_get(engine: &Engine, url: String) -> Result<reqwest::Response, Retryable<String>> {
    let cookie: HeaderValue = match engine.cookie.header().await {
        Ok(h) => h,
        Err(e) => return Err(Retryable::stop(e)),
    };
    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;

    let response = match engine.http.get(url).header(COOKIE, cookie).send().await {
        Ok(r) => r,
        Err(e) => {
            engine.limiter.refund().await;
            return Err(Retryable::again(format!("request failed: {e}")));
        }
    };
    engine.csrf.observe(response.headers()).await;
    let status = response.status();
    if status.is_success() {
        return Ok(response);
    }
    if status == StatusCode::TOO_MANY_REQUESTS {
        let after = retry::parse_retry_after(response.headers().get(reqwest::header::RETRY_AFTER));
        engine.limiter.note_429(after).await;
        let wait = after.unwrap_or(Duration::from_secs(5));
        return Err(Retryable::after(format!("rate limited (429)"), wait));
    }
    if status == StatusCode::UNAUTHORIZED {
        return Err(Retryable::stop("UNAUTHORIZED: cookie rejected (401)".to_owned()));
    }
    let body = response.text().await.unwrap_or_default();
    let fatal = status.is_client_error();
    let vote = Retryable { err: format!("request failed: {status}: {body}"), again: !fatal, after: None };
    Err(vote)
}

async fn get_json<T>(engine: &Engine, url: String) -> Result<T, String>
where
    T: serde::de::DeserializeOwned,
{
    retry::retry(3, Duration::from_millis(500), Duration::from_secs(8), |_| async {
        match api_get(engine, url.clone()).await {
            Ok(response) => match response.json::<T>().await {
                Ok(value) => Ok(value),
                Err(e) => Err(Retryable::stop(format!("bad json: {e}"))),
            },
            Err(vote) => Err(vote),
        }
    })
    .await
}

// --> [`info`]
fn join_ids(ids: &[i64]) -> String {
    ids.iter().map(|id| id.to_string()).collect::<Vec<_>>().join(",")
}

pub async fn assets_info(engine: &Engine, ids: &[i64]) -> Result<Vec<AssetInfo>, String> {
    let url = format!("https://develop.roblox.com/v1/assets?assetIds={}", join_ids(ids));
    let answer: AssetsInfoResponse = get_json(engine, url).await?;
    Ok(answer.data)
}

pub async fn universe_for_place(engine: &Engine, place_id: i64) -> Result<i64, String> {
    let url = format!("https://games.roblox.com/v1/games/multiget-place-details?placeIds={place_id}");
    let answer: Vec<PlaceDetails> = get_json(engine, url).await?;
    answer
        .first()
        .map(|place| place.universe_id)
        .filter(|universe| *universe > 0)
        .ok_or_else(|| format!("[éclat/catalog] place {place_id} has no universe"))
}

pub async fn user_games(engine: &Engine, user_id: i64) -> Result<GamesResponse, String> {
    let url = format!("https://games.roblox.com/v2/users/{user_id}/games?limit=50");
    get_json(engine, url).await
}

pub async fn group_games(engine: &Engine, group_id: i64) -> Result<GamesResponse, String> {
    let url = format!("https://games.roblox.com/v2/groups/{group_id}/gamesV2?limit=100");
    get_json(engine, url).await
}

async fn membership(engine: &Engine, group_id: i64) -> Result<Membership, String> {
    let url = format!("https://groups.roblox.com/v1/groups/{group_id}/membership");
    get_json(engine, url).await
}

async fn teamcreate(engine: &Engine, universe_id: i64) -> Result<TeamCreate, String> {
    let url = format!("https://develop.roblox.com/v1/universes/{universe_id}/teamcreate");
    get_json(engine, url).await
}

// --> [`access`]
pub async fn can_edit_universe(
    engine: &Engine,
    is_group: bool,
    creator_id: i64,
    universe_id: i64,
) -> Result<(), String> {
    if is_group {
        let ledger = membership(engine, creator_id).await?;
        if ledger.user_role.role.name == "Guest" {
            return Err("[éclat/catalog] account is not in group".to_owned());
        }
        let purse = ledger.permissions.group_economy_permissions;
        if !purse.create_items {
            return Err("[éclat/catalog] account cannot create group items".to_owned());
        }
        if !purse.manage_group_games {
            return Err("[éclat/catalog] account cannot manage group games".to_owned());
        }
        return Ok(());
    }
    match teamcreate(engine, universe_id).await {
        Ok(_) => Ok(()),
        Err(e) if e.contains("UNAUTHORIZED") || e.contains("403") => {
            Err("[éclat/catalog] account cannot edit this place — import a cookie that can".to_owned())
        }
        Err(e) => Err(e),
    }
}
