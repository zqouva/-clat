const $ = (id) => document.getElementById(id);

document.querySelectorAll(".tab").forEach((tab) => {
  tab.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
    document.querySelectorAll(".panel").forEach((p) => p.classList.remove("active"));
    tab.classList.add("active");
    $("tab-" + tab.dataset.tab).classList.add("active");
  });
});

async function health() {
  try {
    const res = await fetch("/health");
    if (!res.ok) return;
    const data = await res.json();
    $("engine-version").textContent = "v" + (data.engine || "?");
    $("protocol-version").textContent = data.protocol || "?";
    const user = data.user || {};
    const rows = [
      ["ENGINE", "v" + (data.engine || "?")],
      ["PILOT", (user.displayName || "?") + " (@" + (user.name || "?") + ")"],
      ["COOKIE", "live"],
      ["TRACKS", String(data.tracks || 32)],
      ["UPLINK", ":8080 + :38073"],
    ];
    $("status-rows").innerHTML = rows
      .map(
        ([tag, val], i) =>
          `<div class="row" style="animation-delay:${i * 90}ms"><span class="tag">${tag}</span><span class="val">${val}</span><span class="hp"></span><span class="sp"></span></div>`
      )
      .join("");
  } catch (_) {
    /* engine mid-restart; next tick fills in */
  }
}

async function status() {
  try {
    const res = await fetch("/status");
    if (!res.ok) return;
    const s = await res.json();
    const total = s.total || 0;
    const done = (s.processed || 0) - (s.failed || 0);
    const pct = total > 0 ? Math.round((done / total) * 100) : 0;
    $("job-pct").textContent = total > 0 ? pct + "%" : "—";
    $("job-phase").textContent = s.phase || "idle";
    $("job-counts").textContent =
      `${done} / ${total} · ${s.failed || 0} failed · ${s.queued || 0} queued`;
    $("job-fill").style.width = pct + "%";
  } catch (_) {
    /* engine mid-restart; next tick fills in */
  }
}

health();
status();
setInterval(status, 500);
setInterval(health, 5000);
