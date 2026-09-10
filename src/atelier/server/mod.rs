
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

// --> [`ports`]
pub const PRIMARY_PORT: u16 = 8080;
pub const COMPAT_PORT: u16 = 38073;

const MAX_DIRECT_BYTES: usize = 64 * 1024 * 1024;

// --> [`serve`]
pub async fn serve(engine: Arc<Engine>, headless: bool) -> Result<(), String> {
    let app = Router::new()
        .route("/", get(poll))
        .route("/reupload", post(reupload))
        .route("/upload", post(upload_direct))
        .route("/cookie", post(import_cookie))
        .route("/settings", post(cache_settings))
        .route("/refresh", post(refresh_list))
        .route("/health", get(health))
        .route("/status", get(status))
        .route("/version", get(version))
        .merge(crate::atelier::console::routes())
        .with_state(engine)
        .layer(DefaultBodyLimit::disable());

    let primary = tokio::net::TcpListener::bind(("127.0.0.1", PRIMARY_PORT))
        .await
        .map_err(|e| format!("[éclat/server] cannot bind :{PRIMARY_PORT}: {e}"))?;
    banner::stage("uplink", format!("listening on 127.0.0.1:{PRIMARY_PORT}"));
    let compat = match tokio::net::TcpListener::bind(("127.0.0.1", COMPAT_PORT)).await {
        Ok(listener) => {
            banner::stage("uplink", format!("compat port on 127.0.0.1:{COMPAT_PORT} (old plugins)"));
            Some(listener)
        }
        Err(e) => {
            banner::warn(format!("compat port :{COMPAT_PORT} is busy ({e}) — continuing on :{PRIMARY_PORT}"));
            None
        }
    };
    println!();
    banner::ok("eclat online. waiting for studio.");
    if !headless {
        open_console(PRIMARY_PORT);
    }

    match compat {
        Some(compat) => {
            let first = axum::serve(primary, app.clone()).with_graceful_shutdown(shutdown_signal());
            let second = axum::serve(compat, app).with_graceful_shutdown(shutdown_signal());
            tokio::select! {
                result = async move { first.await } => report(result, PRIMARY_PORT),
                result = async move { second.await } => report(result, COMPAT_PORT),
            }
        }
        None => {
            let result = axum::serve(primary, app).with_graceful_shutdown(shutdown_signal()).await;
            report(result, PRIMARY_PORT)
        }
    }
}

// --> [`console`]
fn open_console(port: u16) {
    let url = format!("http://127.0.0.1:{port}/console");
    banner::stage("console", format!("menu at {url}"));
    tokio::spawn(async move {
        tokio::time::sleep(std::time::Duration::from_millis(800)).await;
        #[cfg(target_os = "windows")]
        let _ = std::process::Command::new("cmd").args(["/C", "start", &url]).spawn();
        #[cfg(target_os = "macos")]
        let _ = std::process::Command::new("open").arg(&url).spawn();
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        let _ = std::process::Command::new("xdg-open").arg(&url).spawn();
    });
}

fn report(result: Result<(), std::io::Error>, port: u16) -> Result<(), String> {
    match result {
        Ok(()) => {
            banner::info("shutting down.");
            Ok(())
        }
        Err(e) => Err(format!("[éclat/server] server error on :{port}: {e}")),
    }
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}

// --> [`poll`]
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

// --> [`reupload`]
async fn reupload(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let raw: RawRequest = match serde_json::from_slice(&body) {
        Ok(req) => req,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("bad reupload request: {e}")).into_response(),
    };
    if UploadKind::from_asset_type(&raw.asset_type).is_none() {
        return (StatusCode::NOT_FOUND, format!("unknown assetType {:?}", raw.asset_type)).into_response();
    }
    if !raw.plugin_version.is_empty() && raw.plugin_version != banner::PROTOCOL_VERSION {
        banner::warn(format!(
            "plugin speaks {}, engine prefers {} — continuing anyway",
            raw.plugin_version,
            banner::PROTOCOL_VERSION
        ));
    }
    if !engine.jobs.try_start(raw.ids.len() as u32).await {
        return (StatusCode::SERVICE_UNAVAILABLE, "busy with another reupload").into_response();
    }
    engine.queue.drain().await;
    if raw.export_json {
        engine.queue.set_export(Some(export_filename(&raw.asset_type))).await;
    } else {
        engine.queue.set_export(None).await;
    }
    banner::stage("reupload", format!("{} ids received from studio", raw.ids.len()));

    let worker = engine.clone();
    tokio::spawn(async move {
        let started = std::time::Instant::now();
        if let Err(e) = pipeline::reupload(worker.clone(), raw).await {
            banner::err(format!("reupload failed: {e}"));
            worker.queue.finish_export().await;
            worker.jobs.set(Phase::Finishing).await;
        }
        let took = started.elapsed();
        banner::info(format!(
            "reupload took {}h {}m {}s",
            took.as_secs() / 3600,
            took.as_secs() / 60 % 60,
            took.as_secs() % 60
        ));
    });
    (StatusCode::OK, "accepted").into_response()
}

// --> [`upload`]
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
    #[serde(default)]
    encoding: Option<String>,
}

async fn upload_direct(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let req: DirectUpload = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("bad upload request: {e}")).into_response(),
    };
    let kind = match UploadKind::from_asset_type(&req.asset_type) {
        Some(k) => k,
        None => return (StatusCode::NOT_FOUND, format!("unknown assetType {:?}", req.asset_type)).into_response(),
    };
    let name = if req.name.trim().is_empty() {
        format!("eclat-{}", unix_millis())
    } else {
        req.name.clone()
    };
    let clean: String = req.hex.chars().filter(|c| !c.is_whitespace()).collect();
    let data: Vec<u8> = match req.encoding.as_deref().unwrap_or("hex") {
        "base64" => match base64::engine::general_purpose::STANDARD.decode(&clean) {
            Ok(v) => v,
            Err(e) => return (StatusCode::UNPROCESSABLE_ENTITY, format!("bad base64 payload: {e}")).into_response(),
        },
        _ => match hex::decode(&clean) {
            Ok(v) => v,
            Err(e) => return (StatusCode::UNPROCESSABLE_ENTITY, format!("bad hex payload: {e}")).into_response(),
        },
    };
    if data.is_empty() {
        return (StatusCode::UNPROCESSABLE_ENTITY, "empty payload").into_response();
    }
    if data.len() > MAX_DIRECT_BYTES {
        return (StatusCode::PAYLOAD_TOO_LARGE, format!("payload exceeds {MAX_DIRECT_BYTES} bytes")).into_response();
    }
    banner::stage("upload", format!("{} · {} · {} bytes", kind.as_str(), name, data.len()));
    match pipeline::upload_direct(&engine, kind, name.clone(), req.description.clone(), Bytes::from(data), req.group_id).await {
        Ok(id) => {
            banner::swapped(engine.jobs.processed(), engine.jobs.total().max(1), &name, 0, id);
            Json(serde_json::json!({ "assetId": id, "assetType": kind.as_str(), "name": name })).into_response()
        }
        Err(e) => (StatusCode::BAD_GATEWAY, e).into_response(),
    }
}

// --> [`cookie`]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CookieImport {
    #[serde(default)]
    cookie: String,
}

async fn import_cookie(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let req: CookieImport = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("bad cookie request: {e}")).into_response(),
    };
    if req.cookie.trim().is_empty() {
        return (StatusCode::BAD_REQUEST, "empty cookie").into_response();
    }
    match engine.set_cookie(&req.cookie).await {
        Ok(user) => {
            banner::ok(format!("cookie imported: {} (@{})", user.display_name, user.name));
            Json(user).into_response()
        }
        Err(e) => (StatusCode::UNAUTHORIZED, e).into_response(),
    }
}

// --> [`list`]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ListSettings {
    #[serde(default)]
    cache: String,
}

async fn cache_settings(State(engine): State<Arc<Engine>>, body: Bytes) -> Response {
    let req: ListSettings = match serde_json::from_slice(&body) {
        Ok(p) => p,
        Err(e) => return (StatusCode::BAD_REQUEST, format!("bad settings request: {e}")).into_response(),
    };
    let mode = match req.cache.to_lowercase().as_str() {
        "fresh" => crate::atelier::stash::StashMode::Fresh,
        "hour" => crate::atelier::stash::StashMode::Hour,
        "day" => crate::atelier::stash::StashMode::Day,
        "keep" => crate::atelier::stash::StashMode::Keep,
        _ => return (StatusCode::BAD_REQUEST, "unknown cache mode (fresh|hour|day|keep)").into_response(),
    };
    engine.stash.set_mode(mode).await;
    let (infos, places, universes) = engine.stash.stats().await;
    banner::stage("list", format!("update mode: {}", mode.as_str()));
    Json(serde_json::json!({ "cache": mode.as_str(), "infos": infos, "places": places, "universes": universes }))
        .into_response()
}

async fn refresh_list(State(engine): State<Arc<Engine>>) -> Response {
    let cleared = engine.stash.clear().await;
    banner::stage("list", format!("cleared {cleared} saved entries — next run reads fresh"));
    Json(serde_json::json!({ "cleared": cleared })).into_response()
}

// --> [`health`]
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

// --> [`status`]
async fn status(State(engine): State<Arc<Engine>>) -> Response {
    let queued = engine.queue.len().await;
    Json(engine.jobs.snapshot(queued).await).into_response()
}

// --> [`version`]
async fn version() -> Response {
    Json(serde_json::json!({
        "engine": banner::ENGINE_VERSION,
        "protocol": banner::PROTOCOL_VERSION,
        "routes": ["/", "/reupload", "/upload", "/cookie", "/settings", "/refresh", "/health", "/status", "/version", "/console"],
        "pool": { "tracks": crate::atelier::limiter::TRACKS, "minuteBudget": crate::atelier::limiter::MINUTE_BUDGET },
    }))
    .into_response()
}

// --> [`export`]
fn export_filename(asset_type: &str) -> String {
    format!("Output_{asset_type}_{}.json", unix_millis())
}

fn unix_millis() -> u128 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis()).unwrap_or(0)
}
