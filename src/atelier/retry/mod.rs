
use std::future::Future;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

// --> [`verdict`]
pub struct Retryable<E> {
    pub err: E,
    pub again: bool,
    pub after: Option<Duration>,
}

impl<E> Retryable<E> {
    pub fn again(err: E) -> Self {
        Self { err, again: true, after: None }
    }

    pub fn after(err: E, wait: Duration) -> Self {
        Self { err, again: true, after: Some(wait) }
    }

    pub fn stop(err: E) -> Self {
        Self { err, again: false, after: None }
    }
}

// --> [`retry`]
pub async fn retry<T, E, Op, Fut>(tries: u32, base: Duration, cap: Duration, mut op: Op) -> Result<T, E>
where
    Op: FnMut(u32) -> Fut,
    Fut: Future<Output = Result<T, Retryable<E>>>,
{
    let mut attempt = 0u32;
    loop {
        attempt += 1;
        match op(attempt).await {
            Ok(value) => return Ok(value),
            Err(vote) => {
                if !vote.again || attempt >= tries.max(1) {
                    return Err(vote.err);
                }
                let grown = base.saturating_mul(1u32 << attempt.min(6)).min(cap);
                let mut wait = grown;
                if let Some(after) = vote.after {
                    wait = wait.max(after);
                }
                tokio::time::sleep(wait + jitter(Duration::from_millis(250))).await;
            }
        }
    }
}

// --> [`jitter`]
static CHAOS: AtomicU64 = AtomicU64::new(0x9E3779B97F4A7C15);

fn rand_u64() -> u64 {
    let mut x = CHAOS.fetch_add(0x9E3779B97F4A7C15, Ordering::Relaxed);
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    x.wrapping_mul(0x2545F4914F6CDD1D)
}

pub fn jitter(span: Duration) -> Duration {
    let ms = span.as_millis().max(1) as u64;
    Duration::from_millis(rand_u64() % ms)
}

// --> [`retry-after`]
pub fn parse_retry_after(value: Option<&reqwest::header::HeaderValue>) -> Option<Duration> {
    let text = value?.to_str().ok()?;
    text.trim().parse::<u64>().ok().map(Duration::from_secs)
}
