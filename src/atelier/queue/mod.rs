
use std::collections::VecDeque;
use std::sync::atomic::{AtomicU32, Ordering};

use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

// --> [`answer`]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ResponseItem {
    #[serde(rename = "oldId")]
    pub old_id: i64,
    #[serde(rename = "newId")]
    pub new_id: i64,
}

struct ExportSink {
    path: String,
    history: Vec<ResponseItem>,
    since_flush: u32,
}

pub struct ResponseQueue {
    items: Mutex<VecDeque<ResponseItem>>,
    export: Mutex<Option<ExportSink>>,
}

impl ResponseQueue {
    pub fn new() -> Self {
        Self { items: Mutex::new(VecDeque::new()), export: Mutex::new(None) }
    }

    // --> [`add`]
    pub async fn add(&self, item: ResponseItem) {
        self.items.lock().await.push_back(item);
        let mut guard = self.export.lock().await;
        if let Some(sink) = guard.as_mut() {
            sink.history.push(item);
            sink.since_flush += 1;
            if sink.since_flush >= 25 {
                Self::flush_sink(sink).await;
            }
        }
    }

    async fn flush_sink(sink: &mut ExportSink) {
        match serde_json::to_string_pretty(&sink.history) {
            Ok(text) => match tokio::fs::write(&sink.path, text).await {
                Ok(()) => sink.since_flush = 0,
                Err(e) => eprintln!("[éclat/queue] cannot write {}: {e}", sink.path),
            },
            Err(e) => eprintln!("[éclat/queue] cannot encode output json: {e}"),
        }
    }

    // --> [`drain`]
    pub async fn drain(&self) -> Vec<ResponseItem> {
        self.items.lock().await.drain(..).collect()
    }

    pub async fn len(&self) -> usize {
        self.items.lock().await.len()
    }

    // --> [`export`]
    pub async fn set_export(&self, path: Option<String>) {
        let mut guard = self.export.lock().await;
        if let Some(sink) = guard.as_mut() {
            Self::flush_sink(sink).await;
        }
        *guard = path.map(|path| ExportSink { path, history: Vec::new(), since_flush: 0 });
    }

    pub async fn finish_export(&self) {
        let mut guard = self.export.lock().await;
        if let Some(sink) = guard.as_mut() {
            Self::flush_sink(sink).await;
        }
        *guard = None;
    }
}

impl Default for ResponseQueue {
    fn default() -> Self {
        Self::new()
    }
}

// --> [`board`]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Phase {
    Idle,
    Running,
    AwaitingCookie,
    Finishing,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct JobSnapshot {
    pub phase: Phase,
    pub total: u32,
    pub processed: u32,
    pub queued: usize,
}

pub struct JobBoard {
    phase: Mutex<Phase>,
    total: AtomicU32,
    processed: AtomicU32,
}

impl JobBoard {
    pub fn new() -> Self {
        Self { phase: Mutex::new(Phase::Idle), total: AtomicU32::new(0), processed: AtomicU32::new(0) }
    }

    // --> [`begin`]
    pub async fn try_start(&self, total: u32) -> bool {
        let mut phase = self.phase.lock().await;
        match *phase {
            Phase::Idle | Phase::Finishing => {
                *phase = Phase::Running;
                self.total.store(total, Ordering::SeqCst);
                self.processed.store(0, Ordering::SeqCst);
                true
            }
            Phase::Running | Phase::AwaitingCookie => false,
        }
    }

    pub async fn set(&self, phase: Phase) {
        *self.phase.lock().await = phase;
    }

    // --> [`count`]
    pub fn add_processed(&self, n: u32) -> u32 {
        self.processed.fetch_add(n, Ordering::SeqCst) + n
    }

    pub fn processed(&self) -> u32 {
        self.processed.load(Ordering::SeqCst)
    }

    pub fn total(&self) -> u32 {
        self.total.load(Ordering::SeqCst)
    }

    // --> [`done`]
    pub async fn take_finished(&self) -> bool {
        let mut phase = self.phase.lock().await;
        if *phase == Phase::Finishing {
            *phase = Phase::Idle;
            true
        } else {
            false
        }
    }

    pub async fn snapshot(&self, queued: usize) -> JobSnapshot {
        JobSnapshot {
            phase: *self.phase.lock().await,
            total: self.total(),
            processed: self.processed(),
            queued,
        }
    }
}

impl Default for JobBoard {
    fn default() -> Self {
        Self::new()
    }
}
