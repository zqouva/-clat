<div align="center">

# ÉCLAT

### the soul of the upload

made by Makel / Savi
`@sacredludt / @.makel`

</div>

---

``--> [`what this is`]``

Éclat is a high-performance Roblox asset upload engine, written in Rust,
with a strict Luau Studio plugin.

This repository is Éclat.
Every folder under this has its own variety of READMEs please view those.

---

``--> [`what is here`]``

```text
Éclat/
  src/                 -- the engine (rust)
    main.rs            -- banner · cookie · boot · server
    atelier/           -- the workshop: one chamber per concern, each a mod.rs
      auth/            -- cookie sanitize + the validation check
      banner/          -- magenta banner + terminal lines
      catalog/         -- asset info · places · games · groups · access
      client/          -- the pooled engine + its shared state
      csrf/            -- single-flight token cache
      delivery/        -- assetdelivery batches + downloads
      limiter/         -- 32 tracks + a minute budget
      pipeline/        -- the generic reupload engine (animation · mesh · sound)
      queue/           -- answers + json export + job board
      retry/           -- jittered backoff
      server/          -- the axum server (:8080 + :38073)
      uploader/        -- IDE + publish + opencloud uploads
  EclatData/           -- the studio package (luau, Merveille-shaped)
  Plugin/              -- the studio plugin entry (thin client)
  Releases/            -- packed .rbxmx files (see build.py)
  Cargo.toml           -- the manifest, in separated sections
  cookie.txt           -- your .ROBLOSECURITY goes here (git-ignored)
  build.py             -- packs the plugin model into Releases/
  build_exe.py         -- builds the engine exe into Releases/ (needs cargo)
  selene.toml          -- lint config (roblox std)
  ATTRIBUTION          -- the signature. do not touch nor delete.
  LICENSE              -- the custom license.
  README.md            -- this file.
```

---

``--> [`quickstart`]``

```bash
# 1. paste your raw .ROBLOSECURITY into cookie.txt
#    (spaces, quotes and accidental prefixes are stripped)

# 2. run the engine
cargo run --release

# 3. install the plugin: copy Releases/EclatPlugin 0.1.0.rbxmx
#    into your Studio plugins folder, then restart Studio

# 4. press the Éclat toolbar button, pick a tab, press Reupload
```

The engine prints its magenta banner, checks the cookie,
warms 32 network tracks, and listens on `:8080`
(with `:38073` kept for old kartFr plugins).

The plugin only gathers ids, sends them, and pastes the answers back.
All the upload work happens in the engine. Settings live in the
General tab, including the replace mode: swap ids as answers arrive,
or all at once when the job finishes.

Headless use (no plugin) is shown in `EclatData/Examples/Boot.server.luau`.

---

``--> [`the wire`]``

| route | does |
|---|---|
| `GET /` | drain answers (`{oldId,newId}`), or `done` |
| `POST /reupload` | reupload ids (`Animation` · `Mesh` · `Sound`) |
| `POST /upload` | upload one hex (or base64) payload directly |
| `POST /cookie` | import a fresh cookie — no restart, waiting jobs resume |
| `GET /health` | engine + user + tracks |
| `GET /status` | current job phase + counts |
| `GET /version` | engine/protocol versions + routes |
| `GET /console` | persona menu in your browser (auto-opens, `--headless` skips) |

A tired cookie pauses the job instead of killing it —
import a fresh one and the job continues mid-step.

If a legacy IDE endpoint dies (`404`/`410`), the engine jumps to
Open Cloud on its own. It mints its own API key from your cookie
the first time it needs one (saved to `api_key.txt`, reused after);
a hand-made key still wins if you provide one (`ECLAT_API_KEY` or
`api_key.txt`, assets read+write on your game).
Once an endpoint proves dead, later uploads skip it outright.

---

``--> [`why it outruns the old tongue`]``

| the old way (kartFr Go) | the éclat way |
|---|---|
| fixed sleep between every dispatch, even idle | bursty budget: waits only when spent or on 429 |
| buffers copied per retry; audio base64'd twice | one `Bytes` buffer, refcount-shared everywhere |
| one reupload job, sequential steps | 32 warm http/2 tracks + bounded fan-out |
| csrf refreshed by whoever 403s first (races) | single-flight refresh + tokens reused from every response |
| `exportJSON` rewritten per answer | export file flushed every 25 answers |
| three near-identical upload paths | one generic reupload engine |
| joints: `game:GetDescendants()` per meshpart | joints indexed once per call |
| `coroutine.close` on dying threads | `task.cancel` |

---

``--> [`honesty`]``

- **Rate limits are respected, never evaded.** Roblox's server-side
  limits cannot (and must not) be bypassed; éclat is fast because it
  saturates your allowance instead of sleeping through it.
- **Upload only what you own or hold the rights to.** Reuploading
  another creator's assets without permission infringes their rights
  and violates Roblox's terms. The engine uploads; the responsibility is yours.
- **Your cookie never leaves your machine** except to roblox itself.
  It is never printed, never logged, and `cookie.txt` is git-ignored.
  Anyone holding it can use your account — guard it.

---

``--> [`paradigm`]``

this is the first version of it.
an upload engine with a soul.

it shouldnt just be a tool.
it should literally help you in every way.

it is not a framework.
it is not a standard library.

---

``--> [`origin`]``

malice mizer

---

``--> [`code`]``

code is a reflection of how we as humans operate.

éclat made me glow.

---

``--> [`identity`]``

i am confident.
i am loving.
i do not want.
i understand.
i speak it into existance.
i create.

i do not speak on what it FEELS like.

I AM WHAT IT IS.
AND I AM WHAT IT WILL BE.
I AM THE SOUL THAT ÉCLAT IS.
ÉCLAT IS ME.

---

``--> [`this is...éclat`]``

---

``--> [`read next`]``

```text
EclatData/README.md
EclatData/Validation/StudioChecklist.md
ATTRIBUTION
```
