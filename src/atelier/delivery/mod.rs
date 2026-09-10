
use bytes::Bytes;
use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::atelier::client::Engine;
use crate::atelier::uploader::UploadKind;
use crate::atelier::retry::{self, Retryable};

pub const BATCH_MAX: usize = 50;
const BATCH_URL: &str = "https://assetdelivery.roblox.com/v2/assets/batch";

// --> [`petition`]
#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetRequestItem {
    #[serde(default)]
    pub asset_name: String,
    #[serde(default)]
    pub asset_type: String,
    #[serde(default)]
    pub client_insert: bool,
    #[serde(default)]
    pub place_id: i64,
    pub request_id: String,
    #[serde(default)]
    pub script_insert: bool,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub server_place_id: i64,
    #[serde(default)]
    pub universe_id: i64,
    #[serde(default)]
    pub accept: String,
    #[serde(default)]
    pub encoding: String,
    #[serde(default)]
    pub hash: String,
    #[serde(default)]
    pub user_asset_id: i64,
    #[serde(default)]
    pub asset_id: i64,
    #[serde(default)]
    pub version: i32,
    #[serde(default)]
    pub asset_version_id: i64,
    #[serde(default)]
    pub module_place_id: i64,
    #[serde(default)]
    pub asset_format: String,
    #[serde(default, rename = "roblox-assetFormat")]
    pub roblox_asset_format: String,
    #[serde(default)]
    pub content_representation_priority_list: String,
    #[serde(default)]
    pub do_not_fallback_to_baseline_representation: bool,
}

fn is_zero(value: &i64) -> bool {
    *value == 0
}

impl AssetRequestItem {
    pub fn for_id(id: i64) -> Self {
        Self { asset_id: id, request_id: "0".to_owned(), ..Default::default() }
    }
}

// --> [`answer`]
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AssetLocation {
    #[serde(default)]
    pub locations: Vec<LocationEntry>,
    #[serde(default)]
    pub errors: Vec<LocationError>,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LocationEntry {
    #[serde(default)]
    pub asset_format: String,
    #[serde(default)]
    pub location: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone, Default, Deserialize)]
pub struct LocationError {
    #[serde(default, rename = "Code")]
    pub code: i32,
    #[serde(default, rename = "Message")]
    pub message: String,
}

// --> [`batch`]
pub async fn batch(engine: &Engine, ids: &[i64], place_id: i64) -> Result<Vec<AssetLocation>, String> {
    if ids.len() > BATCH_MAX {
        return Err(format!("[éclat/delivery] batch body too large ({} > {BATCH_MAX})", ids.len()));
    }
    let body: Vec<AssetRequestItem> = ids.iter().map(|&id| AssetRequestItem::for_id(id)).collect();

    retry::retry(3, Duration::from_millis(500), Duration::from_secs(8), |_| async {
        let cookie: HeaderValue = match engine.cookie.header().await {
            Ok(h) => h,
            Err(e) => return Err(Retryable::stop(e)),
        };
        engine.limiter.api_budget().await;
        let _permit = engine.limiter.track().await;

        let response = match engine
            .http
            .post(BATCH_URL)
            .header(COOKIE, cookie)
            .header("Content-Type", "application/json")
            .header("Roblox-Place-Id", place_id.to_string())
            .json(&body)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                engine.limiter.refund().await;
                return Err(Retryable::again(format!("assetdelivery unreachable: {e}")));
            }
        };
        engine.csrf.observe(response.headers()).await;
        let status = response.status();
        if status.is_success() {
            return match response.json::<Vec<AssetLocation>>().await {
                Ok(locs) => Ok(locs),
                Err(e) => Err(Retryable::stop(format!("assetdelivery returned bad json: {e}"))),
            };
        }
        if status == StatusCode::TOO_MANY_REQUESTS {
            let after = retry::parse_retry_after(response.headers().get(reqwest::header::RETRY_AFTER));
            engine.limiter.note_429(after).await;
            return Err(Retryable::after("assetdelivery rate limited (429)".to_owned(), after.unwrap_or(Duration::from_secs(5))));
        }
        let text = response.text().await.unwrap_or_default();
        let fatal = status.is_client_error();
        Err(Retryable { err: format!("assetdelivery answered {status}: {text}"), again: !fatal, after: None })
    })
    .await
}

// --> [`download`]
pub async fn download(engine: &Engine, url: &str) -> Result<Bytes, String> {
    retry::retry(3, Duration::from_millis(400), Duration::from_secs(6), |_| async {
        let _permit = engine.limiter.track().await;
        let response = match engine.http.get(url).send().await {
            Ok(r) => r,
            Err(e) => return Err(Retryable::again(format!("cdn unreachable: {e}"))),
        };
        let status = response.status();
        if status.is_success() {
            return match response.bytes().await {
                Ok(body) if !body.is_empty() => Ok(body),
                Ok(_) => Err(Retryable::again("cdn answered with an empty body".to_owned())),
                Err(e) => Err(Retryable::again(format!("cdn body unreadable: {e}"))),
            };
        }
        if status == StatusCode::TOO_MANY_REQUESTS {
            let after = retry::parse_retry_after(response.headers().get(reqwest::header::RETRY_AFTER));
            return Err(Retryable::after("cdn asked for quiet (429)".to_owned(), after.unwrap_or(Duration::from_secs(5))));
        }
        Err(Retryable {
            err: format!("cdn answered {status}"),
            again: status.is_server_error(),
            after: None,
        })
    })
    .await
}

// --> [`fetch`]
pub async fn fetch(
    engine: &Engine,
    kind: UploadKind,
    asset_id: i64,
    first_url: &str,
    places: &[i64],
) -> Result<Bytes, String> {
    if let Ok(data) = download_cookie(engine, first_url).await {
        if looks_right(kind, &data) {
            return Ok(data);
        }
    }
    let direct = format!("https://assetdelivery.roblox.com/v1/asset/?id={asset_id}");
    if let Ok(data) = download(engine, &direct).await {
        if looks_right(kind, &data) {
            return Ok(data);
        }
    }
    if let Ok(data) = download_cookie(engine, &direct).await {
        if looks_right(kind, &data) {
            return Ok(data);
        }
    }
    for place_id in places {
        let locs = match batch(engine, &[asset_id], *place_id).await {
            Ok(locs) => locs,
            Err(_) => continue,
        };
        let loc = match locs.first() {
            Some(loc) => loc,
            None => continue,
        };
        for entry in &loc.locations {
            if entry.location.is_empty() {
                continue;
            }
            if let Ok(data) = download(engine, &entry.location).await {
                if looks_right(kind, &data) {
                    return Ok(data);
                }
            }
            if let Ok(data) = download_cookie(engine, &entry.location).await {
                if looks_right(kind, &data) {
                    return Ok(data);
                }
            }
        }
    }
    Err(format!(
        "no valid bytes for asset {asset_id} anywhere (tried direct + {} places)",
        places.len()
    ))
}

pub async fn download_cookie(engine: &Engine, url: &str) -> Result<Bytes, String> {
    let cookie = engine.cookie.header().await?;
    retry::retry(3, Duration::from_millis(400), Duration::from_secs(6), |_| async {
        let _permit = engine.limiter.track().await;
        let response = match engine.http.get(url).header(COOKIE, cookie.clone()).send().await {
            Ok(r) => r,
            Err(e) => return Err(Retryable::again(format!("cdn unreachable: {e}"))),
        };
        let status = response.status();
        if status.is_success() {
            return match response.bytes().await {
                Ok(body) if !body.is_empty() => Ok(body),
                Ok(_) => Err(Retryable::again("cdn answered with an empty body".to_owned())),
                Err(e) => Err(Retryable::again(format!("cdn body unreadable: {e}"))),
            };
        }
        if status == StatusCode::TOO_MANY_REQUESTS {
            let after = retry::parse_retry_after(response.headers().get(reqwest::header::RETRY_AFTER));
            return Err(Retryable::after("cdn asked for quiet (429)".to_owned(), after.unwrap_or(Duration::from_secs(5))));
        }
        Err(Retryable {
            err: format!("cdn answered {status}"),
            again: status.is_server_error(),
            after: None,
        })
    })
    .await
}

// --> [`shapes`]
pub fn byte_kind(data: &Bytes) -> &'static str {
    if data.starts_with(b"<roblox!") {
        "binary rbxm"
    } else if data.starts_with(b"<roblox") {
        "xml rbxm"
    } else if data.starts_with(b"version ") {
        "mesh"
    } else if data.is_empty() {
        "empty"
    } else {
        "unknown"
    }
}

pub fn looks_right(kind: UploadKind, data: &Bytes) -> bool {
    match kind {
        UploadKind::Animation => data.starts_with(b"<roblox"),
        UploadKind::Mesh => data.len() > 16,
        UploadKind::Audio => !data.is_empty(),
    }
}

pub fn byte_sample(data: &Bytes) -> String {
    let n = data.len().min(80);
    data[..n]
        .iter()
        .map(|b| {
            let c = *b as char;
            if c.is_ascii_graphic() || c == ' ' {
                c
            } else {
                '·'
            }
        })
        .collect()
}

pub fn url_host(url: &str) -> &str {
    url.split("://").nth(1).unwrap_or(url).split('/').next().unwrap_or(url)
}
