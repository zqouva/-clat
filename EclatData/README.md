# Éclat : v.0.1.0 : the soul of the upload
made by Makel/Savi(@sacredludt)

``--> [`what this is`]``

Éclat is the Studio plugin for the éclat engine: strict Luau,
built around one wire. It ships as one model file; the engine
does the work.

The plugin holds:
- one connection to the engine
- hex-streamed binary uploads
- hot cookie import (no restart)
- gathered ids, pasted back on arrival or all at once
- joints indexed once, never per meshpart
---

``--> [`package shape`]``

```text
Eclat/
  init.luau
  README.md
  Core/
    ApiDump.luau
    Connection.luau
    Constants.luau
    Controls.luau
    Cookie.luau
    Filter.luau
    Hex.luau
    Hover.luau
    Input.luau
    Layout.luau
    Panel.luau
    Reupload.luau
    Retry.luau
    Scrollbar.luau
    SearchFilter.luau
    Sections.luau
    StatusCodes.luau
    Templates.luau
    Uplink.luau
    WaitGroup.luau
  Examples/
    Boot.server.luau
    HexUpload.server.luau
  Validation/
    HexValidation.server.luau
    UplinkValidation.server.luau

    README.md
    StudioChecklist.md
```

The plugin model (`Releases/EclatPlugin 0.1.0.rbxmx`) holds
`Main` plus this package without `Examples/` and `Validation/`.

---

``--> [`public surface`]``

The package entry opens the panel:

```luau
local Eclat = require(path.to.Eclat)
Eclat.open(plugin) --> Handle { Widget, Refresh }
Eclat.VERSION --> "1.3.1"
```

Everything else is required straight from `Core/`:

```luau
local Connection = require(Eclat.Core.Connection)
local Cookie = require(Eclat.Core.Cookie)
local Filter = require(Eclat.Core.Filter)
local Hex = require(Eclat.Core.Hex)
local Reupload = require(Eclat.Core.Reupload)
local Uplink = require(Eclat.Core.Uplink)

Uplink.connect(port?) --> link, seed, port
Uplink.reupload(link, petition) --> sent, response
Uplink.uploadBinary(link, assetType, name, raw, description?, groupId?)
Uplink.health(port) --> ok, report?
Uplink.status(port) --> ok, report?

Filter.getIds({ WhitelistedInstances = {...}, Instances = {...} }) --> map
Filter.getIdArray(map) --> { id }
Filter.replaceIds(map, { { oldId = 1, newId = 2 } })

Reupload.run(link, map, job, events) --> outcome

Cookie.sanitize('  ".ROBLOSECURITY=tok"  ') --> "tok"
Cookie.importCookie(port, rawCookie) --> ok, user?

Hex.fromString("hello") --> "68656c6c6f"
Hex.fromBuffer(buffer.fromstring("hi")) --> "6869"
```

The interface pieces (`Constants`, `Input`, `Hover`, `Templates`,
`Layout`, `Controls`, `Sections`, `SearchFilter`, `Scrollbar`,
`Panel`) are used by the panel; require them if you build your own.

---

``--> [`the wire`]``

| route | does |
|---|---|
| `GET /` | drain answers (`{oldId,newId}`), or `done` |
| `POST /reupload` | reupload ids |
| `POST /upload` | upload one hex payload directly |
| `POST /cookie` | import a fresh cookie |
| `GET /health` | engine + user + tracks |
| `GET /status` | current job phase + counts |
| `GET /version` | engine/protocol versions + routes |

The engine listens on `:8080`, with `:38073` kept for old plugins.

---

``--> [`vows`]``

- upload only what you own or hold the rights to.
- the cookie is never printed, never warned, never logged.
- enable HTTP requests in your place for the wire to work
  (game settings → security → enable studio access to APIs is NOT this;
  the place needs HttpService access: Home → Game Settings → Security → Enable HTTP requests).

---

``--> [`read next`]``

```text
Examples/Boot.server.luau
Examples/HexUpload.server.luau
Validation/README.md
Validation/StudioChecklist.md
```
