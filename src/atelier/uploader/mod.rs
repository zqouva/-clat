
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

    pub fn idx(&self) -> usize {
        match self {
            UploadKind::Animation => 0,
            UploadKind::Mesh => 1,
            UploadKind::Audio => 2,
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
    if engine.primary_dead(kind) {
        return opencloud_upload(engine, kind, name, description, data, group, user_id).await;
    }
    let attempt = match kind {
        UploadKind::Audio => audio_upload(engine, name, data.clone(), group).await,
        _ => ide_upload(engine, kind, name, description, data.clone(), group).await,
    };
    match attempt {
        Err(e) if matches!(e.fault, UploadFault::LegacyGone) => {
            if engine.mark_primary_dead(kind) {
                banner::warn(format!(
                    "{} endpoint looks dead, going straight to opencloud",
                    kind.as_str()
                ));
            }
            opencloud_upload(engine, kind, name, description, data, group, user_id).await
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
    if kind == UploadKind::Audio {
        return Err(UploadError::fatal("audio uploads via publish, not IDE"));
    }
    let mut order = [0usize, 1, 2, 3];
    let won = engine.ide_recipe(kind) as usize;
    if won >= 1 && won <= 4 {
        order.swap(0, won - 1);
    }
    let mut reauth: Option<UploadError> = None;
    for idx in order {
        match ide_attempt(engine, kind, name, description, &data, group, idx).await {
            Ok(id) => {
                engine.set_ide_recipe(kind, idx as u8 + 1);
                return Ok(id);
            }
            Err(e) if matches!(e.fault, UploadFault::Reauth(_)) && idx < 2 => {
                reauth = Some(e);
            }
            Err(e) if matches!(e.fault, UploadFault::LegacyGone) => {}
            Err(e) => {
                engine.set_ide_recipe(kind, idx as u8 + 1);
                return Err(e);
            }
        }
    }
    if let Some(e) = reauth {
        return Err(e);
    }
    Err(UploadError::gone())
}

async fn ide_attempt(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: &Bytes,
    group: Option<i64>,
    idx: usize,
) -> Result<i64, UploadError> {
    let (orig, alt) = match kind {
        UploadKind::Animation => (
            "https://www.roblox.com/ide/publish/UploadNewAnimation",
            "https://data.roblox.com/ide/publish/UploadNewAnimation",
        ),
        UploadKind::Mesh => (
            "https://data.roblox.com/ide/publish/UploadNewMesh",
            "https://www.roblox.com/ide/publish/UploadNewMesh",
        ),
        UploadKind::Audio => return Err(UploadError::fatal("audio uploads via publish, not IDE")),
    };
    let base = if idx % 2 == 0 { orig } else { alt };
    let keyed = idx >= 2;
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

    let mut req = engine.http.post(url);
    if keyed {
        let key = match engine.opencloud_key().await {
            Some(key) => key,
            None => return Err(UploadError::gone()),
        };
        req = req.header("x-api-key", key);
    } else {
        let cookie: HeaderValue = engine.cookie.header().await.map_err(UploadError::fatal)?;
        let csrf = engine.csrf.get().await;
        req = req.header(COOKIE, cookie).header("x-csrf-token", csrf);
    }

    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;
    let response = match req.body(data.clone()).send().await {
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
    if keyed && (status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN) {
        return Err(UploadError::gone());
    }
    if status == StatusCode::GONE
        || status == StatusCode::NOT_FOUND
        || status == StatusCode::METHOD_NOT_ALLOWED
        || status == StatusCode::BAD_REQUEST
    {
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
    if status == StatusCode::GONE
        || status == StatusCode::NOT_FOUND
        || status == StatusCode::METHOD_NOT_ALLOWED
    {
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
fn mime_base(kind: UploadKind, data: &Bytes) -> &'static [&'static str] {
    const ANIM_BIN: &[&str] = &["model/x-rbxm", "application/x-rbxm", "model/vnd.roblox.rbxm"];
    const ANIM_XML: &[&str] = &["application/xml", "text/xml", "model/x-rbxm"];
    const MESH: &[&str] = &["application/octet-stream", "model/mesh", "model/x-mesh", "application/x-mesh"];
    const OGG: &[&str] = &["audio/ogg"];
    const MP3: &[&str] = &["audio/mpeg"];
    match kind {
        UploadKind::Animation => {
            if is_xml(data) {
                ANIM_XML
            } else {
                ANIM_BIN
            }
        }
        UploadKind::Mesh => MESH,
        UploadKind::Audio => {
            if data.len() >= 4 && &data[..4] == b"OggS" {
                OGG
            } else {
                MP3
            }
        }
    }
}

fn is_xml(data: &Bytes) -> bool {
    data.len() > 8 && data.starts_with(b"<roblox") && !data.starts_with(b"<roblox!")
}

fn ordered_mimes(engine: &Engine, kind: UploadKind, data: &Bytes) -> Vec<(usize, &'static str)> {
    let base = mime_base(kind, data);
    let mut order: Vec<(usize, &'static str)> = base.iter().copied().enumerate().collect();
    let won = engine.mime_hint(kind) as usize;
    if won >= 1 {
        if let Some(pos) = order.iter().position(|entry| entry.0 == won - 1) {
            order.swap(0, pos);
        }
    }
    order
}

fn opencloud_filename(kind: UploadKind, mime: &str) -> &'static str {
    match kind {
        UploadKind::Animation => "asset.rbxm",
        UploadKind::Mesh => "asset.mesh",
        UploadKind::Audio => {
            if mime == "audio/ogg" {
                "asset.ogg"
            } else {
                "asset.mp3"
            }
        }
    }
}

fn snip(text: &str) -> String {
    let flat: String = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if flat.chars().count() > 300 {
        format!("{}…", flat.chars().take(300).collect::<String>())
    } else {
        flat
    }
}

#[derive(Debug, Default, Deserialize)]
struct CloudOperation {
    #[serde(default)]
    done: bool,
    #[serde(default, rename = "operationId")]
    operation_id: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    path: String,
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

fn op_tail(raw: &str) -> &str {
    match raw.rfind('/') {
        Some(pos) => &raw[pos + 1..],
        None => raw,
    }
}

impl CloudOperation {
    fn op_id(&self) -> &str {
        if !self.operation_id.is_empty() {
            return op_tail(&self.operation_id);
        }
        if !self.name.is_empty() {
            return op_tail(&self.name);
        }
        op_tail(&self.path)
    }

    fn failure(&self) -> Option<String> {
        let error = self.error.as_ref()?;
        if error.message.is_empty() {
            return None;
        }
        Some(error.message.clone())
    }
}

fn immediate_id(text: &str) -> Option<i64> {
    let value: serde_json::Value = serde_json::from_str(text).ok()?;
    if let Some(id) = value.get("assetId").and_then(value_to_id) {
        return Some(id);
    }
    if let Some(id) = value.get("asset_id").and_then(value_to_id) {
        return Some(id);
    }
    value.get("response")?.get("assetId").and_then(value_to_id)
}

struct CloudFail {
    err: UploadError,
    shape_rejected: bool,
}

impl CloudFail {
    fn err(err: UploadError) -> Self {
        Self { err, shape_rejected: false }
    }

    fn shape(err: UploadError) -> Self {
        Self { err, shape_rejected: true }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum CloudShape {
    Multipart,
    Simple,
}

async fn cloud_post(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: &Bytes,
    group: Option<i64>,
    user_id: i64,
    shape: CloudShape,
    mime: &str,
) -> Result<i64, CloudFail> {
    const BASE: &str = "https://apis.roblox.com/assets/v1/assets";
    let key = match engine.opencloud_key().await {
        Some(key) => key,
        None => {
            return Err(CloudFail::err(UploadError::fatal(
                "opencloud has no key — read the setup note above",
            )))
        }
    };
    let url = match shape {
        CloudShape::Multipart => BASE.to_owned(),
        CloudShape::Simple => {
            let mut url = match reqwest::Url::parse(BASE) {
                Ok(url) => url,
                Err(e) => return Err(CloudFail::err(UploadError::fatal(format!("bad url: {e}")))),
            };
            {
                let mut pairs = url.query_pairs_mut();
                pairs.append_pair("request.assetType", kind.as_str());
                pairs.append_pair("request.displayName", name);
                pairs.append_pair("request.description", description);
                match group.filter(|g| *g > 0) {
                    Some(group_id) => {
                        pairs.append_pair("request.creationContext.creator.groupId", &group_id.to_string());
                    }
                    None => {
                        pairs.append_pair("request.creationContext.creator.userId", &user_id.to_string());
                    }
                }
            }
            url.to_string()
        }
    };

    let req = engine.http.post(url);
    let req = match shape {
        CloudShape::Multipart => {
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
            let ask = match reqwest::multipart::Part::text(payload.to_string()).mime_str("application/json") {
                Ok(part) => part,
                Err(e) => {
                    return Err(CloudFail::err(UploadError::fatal(format!("cannot build the form: {e}"))))
                }
            };
            let file = match reqwest::multipart::Part::bytes(data.to_vec()).mime_str(mime) {
                Ok(part) => part,
                Err(e) => {
                    return Err(CloudFail::err(UploadError::fatal(format!("cannot build the form: {e}"))))
                }
            };
            let file = file.file_name(opencloud_filename(kind, mime));
            let form = reqwest::multipart::Form::new().part("request", ask).part("fileContent", file);
            req.multipart(form)
        }
        CloudShape::Simple => req.header("Content-Type", mime).body(data.clone()),
    };
    let req = req.header("x-api-key", key.clone());

    engine.limiter.api_budget().await;
    let _permit = engine.limiter.track().await;
    let response = match req.send().await {
        Ok(r) => r,
        Err(e) => {
            engine.limiter.refund().await;
            return Err(CloudFail::err(UploadError::fatal(format!("opencloud request failed: {e}"))));
        }
    };
    engine.csrf.observe(response.headers()).await;
    let status = response.status();
    let headers = response.headers().clone();
    let text = response.text().await.unwrap_or_default();

    if status.is_success() {
        if let Some(id) = immediate_id(&text) {
            return Ok(id);
        }
        let mut operation: CloudOperation = match serde_json::from_str(&text) {
            Ok(op) => op,
            Err(e) => {
                return Err(CloudFail::err(UploadError::fatal(format!("opencloud sent bad json: {e}"))))
            }
        };
        if let Some(message) = operation.failure() {
            return Err(CloudFail::err(UploadError::fatal(format!("opencloud failed: {message}"))));
        }
        for _ in 0..60 {
            if operation.done {
                break;
            }
            if operation.op_id().is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
            let poll_req = engine.http.get(format!(
                "https://apis.roblox.com/assets/v1/operations/{}",
                operation.op_id()
            ));
            let poll_req = poll_req.header("x-api-key", key.clone());
            engine.limiter.api_budget().await;
            let poll = match poll_req.send().await {
                Ok(r) => r,
                Err(_) => continue,
            };
            engine.csrf.observe(poll.headers()).await;
            if poll.status() == StatusCode::TOO_MANY_REQUESTS {
                engine.limiter.note_429(None).await;
                continue;
            }
            if let Ok(next) = poll.json::<CloudOperation>().await {
                operation = next;
            }
            if let Some(message) = operation.failure() {
                return Err(CloudFail::err(UploadError::fatal(format!("opencloud failed: {message}"))));
            }
        }
        if let Some(message) = operation.failure() {
            return Err(CloudFail::err(UploadError::fatal(format!("opencloud failed: {message}"))));
        }
        match operation.response.as_ref().and_then(|r| value_to_id(&r.asset_id)) {
            Some(id) => return Ok(id),
            None => {
                return Err(CloudFail::err(UploadError::fatal(format!(
                    "opencloud returned no asset id: {}", snip(&text)
                ))))
            }
        }
    }
    if status == StatusCode::TOO_MANY_REQUESTS {
        let after = retry::parse_retry_after(headers.get(reqwest::header::RETRY_AFTER));
        engine.limiter.note_429(after).await;
        return Err(CloudFail::err(UploadError::limited(after)));
    }
    if status == StatusCode::UNAUTHORIZED || status == StatusCode::FORBIDDEN {
        return Err(CloudFail::err(UploadError::fatal(format!(
            "opencloud refused the key ({status}) — delete api_key.txt + restart to mint a fresh one"
        ))));
    }
    if matches!(
        status,
        StatusCode::BAD_REQUEST
            | StatusCode::UNSUPPORTED_MEDIA_TYPE
            | StatusCode::UNPROCESSABLE_ENTITY
            | StatusCode::NOT_ACCEPTABLE
    ) {
        let what = match shape {
            CloudShape::Multipart => "multipart",
            CloudShape::Simple => "simple",
        };
        let err = UploadError::fatal(format!(
            "opencloud refused the {what} upload ({status}): {}",
            snip(&text)
        ));
        return Err(CloudFail::shape(err));
    }
    Err(CloudFail::err(UploadError::fatal(format!("opencloud refused ({}): {}", status, snip(&text)))))
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
    let (first, second) = if engine.shape_hint(kind) == 1 {
        (CloudShape::Simple, CloudShape::Multipart)
    } else {
        (CloudShape::Multipart, CloudShape::Simple)
    };
    match try_shape(engine, kind, name, description, &data, group, user_id, first).await {
        ShapeOut::Id(id) => Ok(id),
        ShapeOut::Dead(err) => Err(err),
        ShapeOut::Refused(first_err) => {
            if first == CloudShape::Simple {
                engine.set_shape_hint(kind, 2);
            }
            match try_shape(engine, kind, name, description, &data, group, user_id, second).await {
                ShapeOut::Id(id) => Ok(id),
                ShapeOut::Dead(err) => Err(err),
                ShapeOut::Refused(second_err) => {
                    let combined = format!("{second_err} · then {first_err}");
                    let lowered = combined.to_lowercase();
                    if lowered.contains("nappropriate") || lowered.contains("moderat") {
                        return Err(UploadError::moderated());
                    }
                    Err(UploadError::fatal(combined))
                }
            }
        }
    }
}

enum ShapeOut {
    Id(i64),
    Dead(UploadError),
    Refused(String),
}

#[allow(clippy::too_many_arguments)]
async fn try_shape(
    engine: &Engine,
    kind: UploadKind,
    name: &str,
    description: &str,
    data: &Bytes,
    group: Option<i64>,
    user_id: i64,
    shape: CloudShape,
) -> ShapeOut {
    let mimes = ordered_mimes(engine, kind, data);
    let what = match shape {
        CloudShape::Multipart => "multipart",
        CloudShape::Simple => "simple",
    };
    let mut attempts: Vec<(&'static str, String)> = Vec::new();
    for entry in mimes.iter() {
        let (orig, mime) = *entry;
        match cloud_post(engine, kind, name, description, data, group, user_id, shape, mime).await {
            Ok(id) => {
                engine.set_mime_hint(kind, orig as u8 + 1);
                engine.set_shape_hint(kind, if shape == CloudShape::Simple { 1 } else { 2 });
                return ShapeOut::Id(id);
            }
            Err(fail) if fail.shape_rejected => {
                attempts.push((mime, fail.err.message));
            }
            Err(fail) => return ShapeOut::Dead(fail.err),
        }
    }
    if mimes.len() == 1 {
        return ShapeOut::Refused(attempts[0].1.clone());
    }
    let full = attempts
        .iter()
        .map(|(mime, message)| format!("{mime} → {message}"))
        .collect::<Vec<_>>()
        .join(" · ");
    let bit = if shape == CloudShape::Multipart { 1 } else { 2 };
    if !engine.mime_noted(kind, bit) {
        banner::warn(format!("opencloud {what} file types for {}: {full}", kind.as_str()));
    }
    let (mime, message) = attempts[attempts.len() - 1].clone();
    ShapeOut::Refused(format!(
        "opencloud refused the {what} upload — all {} file types refused (last {mime}: {message})",
        attempts.len()
    ))
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
