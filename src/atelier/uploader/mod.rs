
use bytes::Bytes;
use reqwest::header::{HeaderValue, COOKIE};
use reqwest::StatusCode;
use serde::{Deserialize, Serialize};
use std::time::Duration;

use crate::atelier::banner;
use crate::atelier::client::Engine;
use crate::atelier::retry;

// --> [`kinds`]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UploadKind {
    Animation,
    Mesh,
    Audio,
}

impl UploadKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            UploadKind::Animation => "Animation",
            UploadKind::Mesh => "Mesh",
            UploadKind::Audio => "Audio",
        }
    }

    pub fn type_id(&self) -> i32 {
        match self {
            UploadKind::Animation => 24,
            UploadKind::Mesh => 4,
            UploadKind::Audio => 3,
        }
    }

    pub fn from_asset_type(value: &str) -> Option<Self> {
        match value {
            "Animation" => Some(UploadKind::Animation),
            "Mesh" => Some(UploadKind::Mesh),
            "Sound" | "Audio" => Some(UploadKind::Audio),
            _ => None,
        }
    }
}

// --> [`faults`]
#[derive(Debug, Clone)]
pub enum UploadFault {
    TokenStale,
    NameModerated,
    RateLimited(Option<Duration>),
    Reauth(String),
    LegacyGone,
    Fatal,
}

#[derive(Debug, Clone)]
pub struct UploadError {
    pub fault: UploadFault,
    pub message: String,
}

impl UploadError {
    fn stale(message: impl Into<String>) -> Self {
        let message = message.into();
        Self { fault: UploadFault::TokenStale, message }
    }
    fn moderated() -> Self {
        Self {
            fault: UploadFault::NameModerated,
            message: "name moderated by roblox".to_owned(),
        }
    }
    fn limited(after: Option<Duration>) -> Self {
        Self { fault: UploadFault::RateLimited(after), message: "roblox asked for quiet (429)".to_owned() }
    }
    fn reauth(message: impl Into<String>) -> Self {
        let message = message.into();
        Self { fault: UploadFault::Reauth(message.clone()), message }
    }
    fn gone() -> Self {
        Self {
            fault: UploadFault::LegacyGone,
            message: "legacy IDE endpoint is gone (410)".to_owned(),
        }
    }
    pub fn fatal(message: impl Into<String>) -> Self {
        let message = message.into();
        Self { fault: UploadFault::Fatal, message }
    }
}

impl std::fmt::Display for UploadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

// --> [`once`]
pub async fn upload_once(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: Bytes,
    group: Option<i64>,
    user_id: i64,
) -> Result<i64, UploadError> {
    let attempt = match kind {
        UploadKind::Audio => audio_upload(engine, name, data.clone(), group).await,
        _ => ide_upload(engine, kind, name, description, data.clone(), group).await,
    };
    match attempt {
        Err(e) if matches!(e.fault, UploadFault::LegacyGone) => {
            if engine.opencloud_key.read().await.is_some() {
                banner::warn("legacy IDE endpoint is gone (410), falling back to opencloud");
                opencloud_upload(engine, kind, name, description, data, group, user_id).await
            } else {
                Err(UploadError::fatal(
                    "legacy IDE endpoint is gone (410) and no opencloud key is set — add ECLAT_API_KEY or api_key.txt (create.roblox.com → credentials → api keys → assets:write)",
                ))
            }
        }
        other => other,
    }
}

// --> [`ide`]
async fn ide_upload(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: Bytes,
    group: Option<i64>,
) -> Result<i64, UploadError> {
    let base = match kind {
        UploadKind::Animation => "https://www.roblox.com/ide/publish/UploadNewAnimation",
        UploadKind::Mesh => "https://data.roblox.com/ide/publish/UploadNewMesh",
        UploadKind::Audio => return Err(UploadError::fatal("audio uploads via publish, not IDE")),
    };
    let mut url = reqwest::Url::parse(base).map_err(|e| UploadError::fatal(format!("bad url: {e}")))?;
    url.query_pairs_mut()
        .append_pair("assetTypeName", kind.as_str())
        .append_pair("name", name)
        .append_pair("description", description);
    if let Some(group_id) = group {
        if group_id > 0 {
            url.query_pairs_mut().append_pair("groupId", &group_id.to_string());
        }
    }

    let cookie: HeaderValue = engine.cookie.header().await.map_err(UploadError::fatal)?;
    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;
    let csrf = engine.csrf.get().await;

    let response = match engine
        .http
        .post(url)
        .header(COOKIE, cookie)
        .header("x-csrf-token", csrf)
        .body(data)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            engine.limiter.refund().await;
            return Err(UploadError::fatal(format!("upload request failed: {e}")));
        }
    };
    engine.csrf.observe(response.headers()).await;
    let status = response.status();
    let headers = response.headers().clone();
    let body = response.text().await.unwrap_or_default();

    if status == StatusCode::OK {
        return body.trim().parse::<i64>().map_err(|_| {
            UploadError::fatal(format!("roblox answered 200 with an unparsable id: {body:?}"))
        });
    }
    if status == StatusCode::GONE {
        return Err(UploadError::gone());
    }
    if status == StatusCode::TOO_MANY_REQUESTS {
        let after = retry::parse_retry_after(headers.get(reqwest::header::RETRY_AFTER));
        engine.limiter.note_429(after).await;
        return Err(UploadError::limited(after));
    }
    if status == StatusCode::FORBIDDEN {
        if body == "NotLoggedIn" {
            return Err(UploadError::reauth("cookie expired (NotLoggedIn)"));
        }
        if body.contains("Token Validation Failed") || body.contains("XSRF") {
            return Err(UploadError::stale("csrf rejected (403), refreshing"));
        }
    }
    if status == StatusCode::UNPROCESSABLE_ENTITY && body.contains("Inappropriate name") {
        return Err(UploadError::moderated());
    }
    if body.contains("Token Validation Failed") {
        return Err(UploadError::stale(format!("csrf rejected ({status}), refreshing")));
    }
    Err(UploadError::fatal(format!("upload failed: {status} {body}")))
}

// --> [`audio`]
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct AudioBody {
    name: String,
    file: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    group_id: Option<i64>,
    estimated_file_size: i64,
    estimated_duration: f64,
    asset_privacy: i32,
}

#[derive(Debug, Default, Deserialize)]
struct AudioAnswer {
    #[serde(default)]
    id: Option<i64>,
    #[serde(default)]
    errors: Vec<AudioFault>,
}

#[allow(dead_code)]
#[derive(Debug, Default, Deserialize)]
struct AudioFault {
    #[serde(default)]
    code: i64,
    #[serde(default)]
    message: String,
}

async fn audio_upload(
    engine: &Engine,
    name: &str,
    data: Bytes,
    group: Option<i64>,
) -> Result<i64, UploadError> {
    use base64::Engine as _;
    let size = data.len() as i64;
    let file = base64::engine::general_purpose::STANDARD.encode(&data);
    let payload = AudioBody {
        name: name.to_owned(),
        file,
        group_id: group.filter(|g| *g > 0),
        estimated_file_size: size,
        estimated_duration: 0.0,
        asset_privacy: 0,
    };

    let cookie: HeaderValue = engine.cookie.header().await.map_err(UploadError::fatal)?;
    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;
    let csrf = engine.csrf.get().await;

    let response = match engine
        .http
        .post("https://publish.roblox.com/v1/audio")
        .header(COOKIE, cookie)
        .header("x-csrf-token", csrf)
        .json(&payload)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            engine.limiter.refund().await;
            return Err(UploadError::fatal(format!("audio request failed: {e}")));
        }
    };
    engine.csrf.observe(response.headers()).await;
    let status = response.status();
    let headers = response.headers().clone();
    let answer: AudioAnswer = response.json().await.unwrap_or_default();

    if status == StatusCode::OK {
        if let Some(id) = answer.id {
            return Ok(id);
        }
        let message = answer.errors.first().map(|e| e.message.clone()).unwrap_or_else(|| "publish endpoint stayed silent".to_owned());
        return Err(UploadError::fatal(message));
    }
    if status == StatusCode::GONE {
        return Err(UploadError::gone());
    }
    if status == StatusCode::TOO_MANY_REQUESTS {
        let message = answer.errors.first().map(|e| e.message.as_str()).unwrap_or("");
        if message.contains("quota") {
            return Err(UploadError::reauth("audio quota exceeded — import a cookie from another account"));
        }
        let after = retry::parse_retry_after(headers.get(reqwest::header::RETRY_AFTER));
        engine.limiter.note_429(after).await;
        return Err(UploadError::limited(after));
    }
    if status == StatusCode::FORBIDDEN {
        return Err(UploadError::stale("csrf rejected (403), refreshing"));
    }
    if status == StatusCode::UNAUTHORIZED {
        return Err(UploadError::reauth("cookie expired (publish refused us)"));
    }
    if status == StatusCode::BAD_REQUEST {
        let message = answer.errors.first().map(|e| e.message.as_str()).unwrap_or("");
        if message.contains("moderated") {
            return Err(UploadError::moderated());
        }
        return Err(UploadError::fatal(format!("publish refused: {message}")));
    }
    let message = answer.errors.first().map(|e| e.message.as_str()).unwrap_or("");
    Err(UploadError::fatal(format!("audio upload failed: {status} {message}")))
}

// --> [`opencloud`]
fn opencloud_mime(kind: UploadKind) -> &'static str {
    match kind {
        UploadKind::Animation => "model/x-rbxm",
        UploadKind::Mesh => "model/x-file-mesh-data",
        UploadKind::Audio => "audio/mpeg",
    }
}

#[derive(Debug, Default, Deserialize)]
struct CloudOperation {
    #[serde(default)]
    done: bool,
    #[serde(default, rename = "operationId")]
    operation_id: String,
    #[serde(default)]
    response: Option<CloudResponse>,
    #[serde(default)]
    error: Option<CloudError>,
}

#[derive(Debug, Default, Deserialize)]
struct CloudResponse {
    #[serde(default, rename = "assetId")]
    asset_id: serde_json::Value,
}

#[derive(Debug, Default, Deserialize)]
struct CloudError {
    #[serde(default)]
    message: String,
}

fn value_to_id(value: &serde_json::Value) -> Option<i64> {
    match value {
        serde_json::Value::Number(n) => n.as_i64(),
        serde_json::Value::String(s) => s.trim().parse::<i64>().ok(),
        _ => None,
    }
}

async fn opencloud_upload(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: Bytes,
    group: Option<i64>,
    user_id: i64,
) -> Result<i64, UploadError> {
    let key = engine
        .opencloud_key
        .read()
        .await
        .clone()
        .ok_or_else(|| UploadError::fatal("opencloud fallback needs ECLAT_API_KEY or api_key.txt"))?;

    let creator = match group.filter(|g| *g > 0) {
        Some(group_id) => serde_json::json!({ "groupId": group_id.to_string() }),
        None => serde_json::json!({ "userId": user_id.to_string() }),
    };
    let payload = serde_json::json!({
        "assetType": kind.as_str(),
        "displayName": name,
        "description": description,
        "creationContext": { "creator": creator },
    });

    let file = reqwest::multipart::Part::bytes(data.to_vec())
        .mime_str(opencloud_mime(kind))
        .map_err(|e| UploadError::fatal(format!("cannot build the form: {e}")))?;
    let form = reqwest::multipart::Form::new()
        .text("request", payload.to_string())
        .part("fileContent", file);

    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;
    let response = match engine
        .http
        .post("https://apis.roblox.com/assets/v1/assets")
        .header("x-api-key", key)
        .multipart(form)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            engine.limiter.refund().await;
            return Err(UploadError::fatal(format!("opencloud request failed: {e}")));
        }
    };
    let status = response.status();
    let headers = response.headers().clone();
    let text = response.text().await.unwrap_or_default();
    if status == StatusCode::TOO_MANY_REQUESTS {
        let after = retry::parse_retry_after(headers.get(reqwest::header::RETRY_AFTER));
        engine.limiter.note_429(after).await;
        return Err(UploadError::limited(after));
    }
    if !status.is_success() {
        return Err(UploadError::fatal(format!("opencloud refused ({status}): {text}")));
    }
    let mut operation: CloudOperation =
        serde_json::from_str(&text).map_err(|e| UploadError::fatal(format!("opencloud sent bad json: {e}")))?;

    // --> [`wait`]
    for _ in 0..12 {
        if operation.done {
            break;
        }
        if operation.operation_id.is_empty() {
            break;
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
        let key = engine.opencloud_key.read().await.clone().unwrap_or_default();
        engine.limiter.api_budget().await;
        let _permit = engine.limiter.track().await;
        let poll = match engine
            .http
            .get(format!("https://apis.roblox.com/assets/v1/operations/{}", operation.operation_id))
            .header("x-api-key", key)
            .send()
            .await
        {
            Ok(r) => r,
            Err(_) => continue,
        };
        if poll.status() == StatusCode::TOO_MANY_REQUESTS {
            engine.limiter.note_429(None).await;
            continue;
        }
        if let Ok(next) = poll.json::<CloudOperation>().await {
            operation = next;
        }
    }

    if let Some(error) = operation.error {
        if !error.message.is_empty() {
            return Err(UploadError::fatal(format!("opencloud failed: {}", error.message)));
        }
    }
    operation
        .response
        .as_ref()
        .and_then(|r| value_to_id(&r.asset_id))
        .ok_or_else(|| UploadError::fatal(format!("opencloud returned no asset id: {text}")))
}

// --> [`grant`]
pub async fn grant_universe_use(engine: &Engine, asset_id: i64, universe_id: i64) -> Result<(), String> {
    let payload = serde_json::json!({
        "requests": [{ "subjectType": "Universe", "subjectId": universe_id.to_string(), "action": "Use" }]
    });
    for attempt in 1..=3u32 {
        let cookie: HeaderValue = engine.cookie.header().await?;
        engine.limiter.api_budget().await;
        let _permit = engine.limiter.track().await;
        let csrf = engine.csrf.header_value().await?;
        let response = match engine
            .http
            .patch(format!("https://apis.roblox.com/asset-permissions-api/v1/assets/{asset_id}/permissions"))
            .header(COOKIE, cookie)
            .header("x-csrf-token", csrf)
            .json(&payload)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                engine.limiter.refund().await;
                if attempt >= 3 {
                    return Err(format!("permission request failed: {e}"));
                }
                tokio::time::sleep(Duration::from_millis(400) + retry::jitter(Duration::from_millis(300))).await;
                continue;
            }
        };
        engine.csrf.observe(response.headers()).await;
        let status = response.status();
        if status.is_success() {
            return Ok(());
        }
        if status == StatusCode::FORBIDDEN {
            let _ = engine.csrf.refresh().await;
            continue;
        }
        if status == StatusCode::TOO_MANY_REQUESTS {
            let after = retry::parse_retry_after(response.headers().get(reqwest::header::RETRY_AFTER));
            engine.limiter.note_429(after).await;
            tokio::time::sleep(after.unwrap_or(Duration::from_secs(3))).await;
            continue;
        }
        let text = response.text().await.unwrap_or_default();
        if attempt >= 3 {
            return Err(format!("permission grant refused ({status}): {text}"));
        }
        tokio::time::sleep(Duration::from_millis(400)).await;
    }
    Err("permission grant unanswered".to_owned())
}
