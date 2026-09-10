use std::sync::Arc;

use axum::http::header;
use axum::response::{Html, IntoResponse};
use axum::routing::get;
use axum::Router;

use crate::atelier::client::Engine;

const PAGE: &str = include_str!("page.html");
const STYLE: &str = include_str!("style.css");
const APP: &str = include_str!("app.js");

const LOGO: &[u8] = include_bytes!("../../../assets/logo.png");
const MOON: &[u8] = include_bytes!("../../../assets/moon.png");
const ICON_ANIMATION: &[u8] = include_bytes!("../../../assets/icon-animation.png");
const ICON_MESH: &[u8] = include_bytes!("../../../assets/icon-mesh.png");
const ICON_SOUND: &[u8] = include_bytes!("../../../assets/icon-sound.png");

// --> [`routes`]
pub fn routes() -> Router<Arc<Engine>> {
    Router::new()
        .route("/console", get(page))
        .route("/console/style.css", get(style))
        .route("/console/app.js", get(app))
        .route("/console/logo.png", get(logo))
        .route("/console/moon.png", get(moon))
        .route("/console/icon-animation.png", get(icon_animation))
        .route("/console/icon-mesh.png", get(icon_mesh))
        .route("/console/icon-sound.png", get(icon_sound))
}

// --> [`page`]
async fn page() -> Html<&'static str> {
    Html(PAGE)
}

async fn style() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/css; charset=utf-8")], STYLE)
}

async fn app() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/javascript; charset=utf-8")], APP)
}

async fn logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], LOGO)
}

async fn moon() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], MOON)
}

async fn icon_animation() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], ICON_ANIMATION)
}

async fn icon_mesh() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], ICON_MESH)
}

async fn icon_sound() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], ICON_SOUND)
}
