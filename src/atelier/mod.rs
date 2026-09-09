//! --> ["atelier"]
//!
//! --> the workshop beneath the banner. every concern its own chamber,
//! --> every chamber its own track (`mod.rs`). nothing loose, nothing lost.
//!
//! --> chambers:
//! -->   auth     · cookie rites + the validation handshake
//! -->   banner   · magenta ink + pipeline psalms
//! -->   catalog  · roblox librarians (assets, places, games, groups)
//! -->   client   · the warm-pooled engine + its shared soul
//! -->   csrf     · the single-flight token candle
//! -->   delivery · assetdelivery batches + one-buffer downloads
//! -->   limiter  · 32 tracks + a bursty minute budget (never a fixed sleep)
//! -->   pipeline · the generic carry-engine (animation · mesh · sound)
//! -->   queue    · answered prayers (old → new) + json chronicles
//! -->   retry    · jittered backoff liturgy
//! -->   server   · the axum altar (:8080, + :38073 for old pilgrims)
//! -->   uploader · IDE + publish + opencloud tongues

pub mod auth;
pub mod banner;
pub mod catalog;
pub mod client;
pub mod csrf;
pub mod delivery;
pub mod limiter;
pub mod pipeline;
pub mod queue;
pub mod retry;
pub mod server;
pub mod uploader;

pub use client::Engine;
