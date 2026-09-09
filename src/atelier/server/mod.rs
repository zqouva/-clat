//! --> ["server"]
//!
//! --> the axum altar where studio kneels.
//! --> :8080 is the first altar; :38073 stays lit for old pilgrims
//! --> (the kartFr plugin speaks here without knowing our name).
//!
//! --> verses:
//! -->   GET  /          · drink answers (old → new), or "done"
//! -->   POST /reupload   · carry a pilgrimage of ids (old-plugin tongue)
//! -->   POST /upload     · carry one hex/streamed payload straight home
//! -->   POST /cookie     · import a hot .ROBLOSECURITY (no restart)
//! -->   GET  /health     · are we breathing?
//! -->   GET  /status     · where walks the pilgrimage?
//! -->   GET  /version    · names + numbers
//!
//! --> bodies are read raw and decoded by hand: the old plugin
//! --> posts json without a content-type, and grace accepts all.

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use axum::extract::{DefaultBodyLimit, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use base64::Engine as _;
use bytes::Bytes;
use serde::Deserialize;

use crate::atelier::banner;
use crate::atelier::client::Engine;
use crate::atelier::pipeline::{self, RawRequest};
use crate::atelier::queue::Phase;
use crate::atelier::uploader::UploadKind;

// --> ["altars"]
pub const PRIMARY_PORT: u16 = 8080;
pub const COMPAT_PORT: u16 = 38073;

/// --> decoded payload ceiling for POST /upload (64 MiB of true bytes).
const MAX_DIRECT_BYTES: usize = 64 * 1024 * 1024;

// --> ["serve"]
pub async fn serve(engine: Arc<Engine>) -> Result<(), String> {
    let app = Router::new()
        .route("/", get(poll))
        .route("/reupload", post(reupload))
        .route("/upload", post(upload_direct))
        .route("/cookie", post(import_cookie))
        .route("/health", get(health))
        .route("/status", get(status))
        .route("/version", get(version))
        .with_state(engine)
        .layer(DefaultBodyLimit::disable());

    let primary = tokio::net::TcpListener::bind(("127.0.0.1", PRIMARY_PORT))
        .await
        .map_err(|e| format!("[éclat/server] cannot kneel on :{PRIMARY_PORT}: {e}"))?;
    banner::stage("uplink", format!("listening on 127.0.0.1:{PRIMARY_PORT}"));
    let compat = match tokio::net::TcpListener::bind(("127.0.0.1", COMPAT_PORT)).await {
        Ok(listener) => {
            banner::stage("uplink", format!("compat altar on 127.0.0.1:{COMPAT_PORT} (old pilgrims welcome)"));
            Some(listener)
        }
        Err(e) => {
            banner::warn(format!("compat port :{COMPAT_PORT} is busy ({e}) — continuing on :{PRIMARY_PORT}"));
            None
        }
    };
    println!();
    banner::ok("éclat is online — waiting for studio to kneel.");

    match compat {
        Some(compat) => {
            let first = axum::serve(primary, app.clone()).with_graceful_shutdown(shutdown_rite());
            let second = axum::serve(compat, app).with_graceful_shutdown(shutdown_rite());
            tokio::pin!(first);
            tokio::pin!(second);
            tokio::select! {
                result = &mut first => report(result, PRIMARY_PORT),
                result = &mut second => report(result, COMPAT_PORT),
            }
        }
        None => {
            let result = axum::serve(primary, app).with_graceful_shutdown(shutdown_rite()).await;
            report(result, PRIMARY_PORT)
        }
    }
}

fn report(result: Result<(), std::io::Error>, port: u16) -> Result<(), String> {
    match result {
        Ok(()) => {
            banner::info("farewell — éclat rests.");
            Ok(())
        }
        Err(e) => Err(format!("[éclat/server] the :{port} altar fell: {e}")),
    }
}

async fn shutdown_rite() {
    let _ = tokio::signal::ctrl_c().await;
}

// --> ["poll"]
// --> studio drinks: answers as json, "done" once when the walk ends,
// --> silence otherwise. the old covenant, kept word for word.
async fn poll(State(engine): State<Arc<Engine>>) -> Response {
    let items = engine.queue.drain().await;
    if !items.is_empty() {
        return Json(items).into_response();
    }
    if engine.jobs.take_finished().await {
        return (StatusCode::OK, "done").into_response();
    }
    (StatusCode::OK, "").into_response()
}

// --> ["reupload"]
async fn reupload(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let raw: RawRequest = match serde_json::from_slice(&body) {
        Ok(psalm) => psalm,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("malformed reupload psalm: {e}")).into_response(),
    };
    if UploadKind::from_asset_type(&raw.asset_type).is_none() {
        return (StatusCode::NOT_FOUND, format!("unknown assetType {:?}", raw.asset_type)).into_response();
    }
    if !raw.plugin_version.is_empty() && raw.plugin_version != banner::PROTOCOL_VERSION {
        banner::warn(format!(
            "plugin speaks {}, engine prefers {} — continuing in grace",
            raw.plugin_version,
            banner::PROTOCOL_VERSION
        ));
    }
    if !engine.jobs.try_start(raw.ids.len() as u32).await {
        return (StatusCode::SERVICE_UNAVAILABLE, "éclat is already carrying a pilgrimage").into_response();
    }
    // --> a fresh walk drinks no stale answers.
    engine.queue.drain().await;
    if raw.export_json {
        engine.queue.set_export(Some(export_filename(&raw.asset_type))).await;
    } else {
        engine.queue.set_export(None).await;
    }
    banner::stage("reupload", format!("{} ids received from studio", raw.ids.len()));

    let pilgrim = engine.clone();
    tokio::spawn(async move {
        let started = std::time::Instant::now();
        if let Err(e) = pipeline::reupload(pilgrim.clone(), raw).await {
            banner::err(format!("pilgrimage failed: {e}"));
            pilgrim.queue.finish_export().await;
            pilgrim.jobs.set(Phase::Finishing).await;
        }
        let walked = started.elapsed();
        banner::info(format!(
            "pilgrimage walked {}h {}m {}s",
            walked.as_secs() / 3600,
            walked.as_secs() / 60 % 60,
            walked.as_secs() % 60
        ));
    });
    (StatusCode::OK, "carrying").into_response()
}

// --> ["upload"]
// --> one payload, hex-dressed (or base64), carried straight home.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct DirectUpload {
    #[serde(default)]
    asset_type: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    group_id: Option<i64>,
    #[serde(default)]
    hex: String,
    /// --> "hex" (the verse) or "base64" (the dialect).
    #[serde(default)]
    encoding: Option<String>,
}

async fn upload_direct(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let prayer: DirectUpload = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("malformed upload prayer: {e}")).into_response(),
    };
    let kind = match UploadKind::from_asset_type(&prayer.asset_type) {
        Some(k) => k,
        None => return (StatusCode::NOT_FOUND, format!("unknown assetType {:?}", prayer.asset_type)).into_response(),
    };
    let name = if prayer.name.trim().is_empty() {
        format!("eclat-{}", unix_millis())
    } else {
        prayer.name.clone()
    };
    // --> studio may breathe whitespace between verses; forgive it.
    let dressed: String = prayer.hex.chars().filter(|c| !c.is_whitespace()).collect();
    let data: Vec<u8> = match prayer.encoding.as_deref().unwrap_or("hex") {
        "base64" => match base64::engine::general_purpose::STANDARD.decode(&dressed) {
            Ok(v) => v,
            Err(e) => return (StatusCode::UNPROCESSABLE_ENTITY, format!("base64 verse unreadable: {e}")).into_response(),
        },
        _ => match hex::decode(&dressed) {
            Ok(v) => v,
            Err(e) => return (StatusCode::UNPROCESSABLE_ENTITY, format!("hex verse unreadable: {e}")).into_response(),
        },
    };
    if data.is_empty() {
        return (StatusCode::UNPROCESSABLE_ENTITY, "the offering is empty").into_response();
    }
    if data.len() > MAX_DIRECT_BYTES {
        return (StatusCode::PAYLOAD_TOO_LARGE, format!("the offering exceeds {MAX_DIRECT_BYTES} bytes")).into_response();
    }
    banner::stage("upload", format!("{} · {} · {} bytes", kind.as_str(), name, data.len()));
    match pipeline::upload_direct(&engine, kind, name.clone(), prayer.description.clone(), Bytes::from(data), prayer.group_id).await {
        Ok(id) => {
            banner::carried(engine.jobs.processed(), engine.jobs.total().max(1), &name, 0, id);
            Json(serde_json::json!({ "assetId": id, "assetType": kind.as_str(), "name": name })).into_response()
        }
        Err(e) => (StatusCode::BAD_GATEWAY, e).into_response(),
    }
}

// --> ["cookie"]
// --> import a hot cookie: validate, swap, persist, ring the bell.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CookieImport {
    #[serde(default)]
    cookie: String,
}

async fn import_cookie(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let prayer: CookieImport = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("malformed cookie prayer: {e}")).into_response(),
    };
    if prayer.cookie.trim().is_empty() {
        return (StatusCode::BAD_REQUEST, "the vessel is empty").into_response();
    }
    match engine.set_cookie(&prayer.cookie).await {
        Ok(user) => {
            banner::ok(format!("cookie imported — welcome, {} (@{})", user.display_name, user.name));
            Json(user).into_response()
        }
        Err(e) => (StatusCode::UNAUTHORIZED, e).into_response(),
    }
}

// --> ["health"]
async fn health(State(engine): State<Arc<Engine>>) -> Response {
    Json(serde_json::json!({
        "status": "online",
        "engine": banner::ENGINE_VERSION,
        "protocol": banner::PROTOCOL_VERSION,
        "user": engine.user().await,
        "tracks": crate::atelier::limiter::TRACKS,
    }))
    .into_response()
}

// --> ["status"]
async fn status(State(engine): State<Arc<Engine>>) -> Response {
    let queued = engine.queue.len().await;
    Json(engine.jobs.snapshot(queued).await).into_response()
}

// --> ["version"]
async fn version() -> Response {
    Json(serde_json::json!({
        "engine": banner::ENGINE_VERSION,
        "protocol": banner::PROTOCOL_VERSION,
        "routes": ["/", "/reupload", "/upload", "/cookie", "/health", "/status", "/version"],
        "pool": { "tracks": crate::atelier::limiter::TRACKS, "minuteBudget": crate::atelier::limiter::MINUTE_BUDGET },
    }))
    .into_response()
}

// --> ["chronicle"]
fn export_filename(asset_type: &str) -> String {
    format!("Output_{asset_type}_{}.json", unix_millis())
}

fn unix_millis() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0)
}
