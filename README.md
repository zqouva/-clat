<div align="center">

# ÉCLAT

### the soul of the upload

made by Makel / Savi
`@sacredludt / @.makel`

</div>

---

`--> ["what this is"]`

Éclat is a high-performance Roblox asset upload engine, written in Rust,
with a strict Luau tongue for Roblox Studio.

This repository is Éclat.
Every instance under this has its own variety of READMEs please view those.

---

`--> ["what is here"]`

```text
Éclat/
  src/                 -- the engine (rust)
    main.rs            -- the conductor: banner · cookie · boot · uplink
    atelier/           -- the workshop: one chamber per concern, each a mod.rs
      auth/            -- cookie rites + the validation handshake
      banner/          -- magenta ink + pipeline psalms
      catalog/         -- asset scrolls · places · games · groups · seals
      client/          -- the warm-pooled engine + its shared soul
      csrf/            -- the single-flight token candle
      delivery/        -- assetdelivery batches + one-buffer downloads
      limiter/         -- 32 tracks + a bursty minute budget
      pipeline/        -- the generic carry-engine (animation · mesh · sound)
      queue/           -- answered prayers + json chronicles + job board
      retry/           -- jittered backoff liturgy
      server/          -- the axum altar (:8080 + :38073)
      uploader/        -- IDE + publish + opencloud tongues
  EclatData/           -- the studio tongue (luau, Merveille-shaped)
  Releases/            -- packed .rbxmx psalms (see build.py)
  Cargo.toml           -- the manifest, in separated verses
  cookie.txt           -- your .ROBLOSECURITY sleeps here (git-ignored)
  build.py             -- packs EclatData into Releases/
  ATTRIBUTION          -- the signature. do not touch nor delete.
  LICENSE              -- the custom license.
  README.md            -- this file.
```

---

`--> ["quickstart"]`

```bash
# 1. paste your raw .ROBLOSECURITY into cookie.txt
#    (spaces, quotes and accidental prefixes are forgiven)

# 2. wake the engine
cargo run --release

# 3. in studio: drop Eclat under ServerStorage.Packages.Eclat,
#    enable HTTP requests, and kneel:
```

```luau
local Eclat = require(game:GetService("ServerStorage").Packages.Eclat)
Eclat.reupload(plugin, ui, {
	WhitelistedInstances = { "Animation" },
	Instances = game:GetDescendants(),
}, "Animation")
```

The engine prints its magenta psalm, validates the cookie,
warms 32 network tracks, and listens on `:8080`
(with `:38073` lit for old kartFr pilgrims).

---

`--> ["the wire"]`

| verse | tongue |
|---|---|
| `GET /` | drink answers (`{oldId,newId}`), or `"done"` |
| `POST /reupload` | carry a pilgrimage of ids (`Animation` · `Mesh` · `Sound`) |
| `POST /upload` | carry one hex (or base64) payload straight home |
| `POST /cookie` | import a hot cookie — no restart, vigils resume |
| `GET /health` | are we breathing? |
| `GET /status` | where walks the pilgrimage? |
| `GET /version` | names + numbers |

A tired cookie pauses the walk (vigil) instead of killing it —
import a fresh one and the pilgrimage continues mid-step.

If roblox retires a legacy IDE altar (`410 Gone`) and you bear an
OpenCloud key (`ECLAT_API_KEY` or `api_key.txt`, assets:write),
the engine falls back to the modern multipart altar automatically.

---

`--> ["why it outruns the old tongue"]`

| the old way (kartFr Go) | the éclat way |
|---|---|
| fixed sleep between every dispatch, even idle | bursty budget: waits only when spent or on 429 |
| buffers copied per retry; audio base64'd twice | one `Bytes` buffer, refcount-shared everywhere |
| one reupload job, one sleepy scheduler | 32 warm http/2 tracks + bounded fan-out |
| csrf refreshed by whoever 403s first (races) | single-flight refresh + free sips off every response |
| `exportJSON` rewritten per answer | chronicle flushed in chapters of 25 |
| three near-identical asset gospels | one generic carry-engine |
| joints: `game:GetDescendants()` per meshpart | joints indexed once per call |
| `coroutine.close` on dying threads | `task.cancel`, the modern rite |

---

`--> ["honesty"]`

- **Rate limits are respected, never evaded.** Roblox's server-side
  limits cannot (and must not) be bypassed; éclat is fast because it
  saturates your allowance instead of sleeping through it.
- **Carry only what you own or hold the rights to.** Reuploading
  another creator's assets without permission infringes their rights
  and violates Roblox's terms. The engine carries; the conscience is yours.
- **Your cookie never leaves your machine** except to roblox itself.
  It is never printed, never logged, and `cookie.txt` is git-ignored.
  Anyone holding it can wear your account — guard it like your soul.

---

`--> ["paradigm"]`

this is the first version of it.
an upload engine with a soul.

it shouldnt just be a tool.
it should literally help you in every way.

it is not a framework.
it is not a standard library.

---

`--> ["origin"]`

malice mizer

---

`--> ["code"]`

code is a reflection of how we as humans operate.

éclat made me glow.

---

`--> ["identity"]`

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

`--> ["this is...éclat"]`

---

`--> ["read next"]`

```text
EclatData/README.md
EclatData/Validation/StudioChecklist.md
ATTRIBUTION
```
