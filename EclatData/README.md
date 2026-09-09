# Éclat : v.0.1.0 : the soul of the upload
made by Makel/Savi(@sacredludt)

`--> ["what this is"]`

Éclat is the studio tongue of the éclat engine: a strict Luau package built around one wire.

The package center is:
- one velvet connection to the engine
- hex-streamed binary uploads
- hot cookie import (no restart)
- gathered ids, rewritten worlds
- joints indexed once, never per meshpart
---

`--> ["package shape"]`

```text
Eclat/
  init.luau
  README.md
  selene.toml
  Core/
    ApiDump.luau
    Connection.luau
    Cookie.luau
    Filter.luau
    Hex.luau
    ReuploadIds.luau
    Retry.luau
    StatusCodes.luau
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

---

`--> ["public surface"]`

The whole rite in one verse:

```luau
Eclat.reupload(plugin, ui, filterOptions, assetType, placeArray?)
```

High verses:

```luau
Eclat.connect(port?) --> link, seed, port
Eclat.stream(link, assetType, name, raw, description?, groupId?)
Eclat.importCookie(port, rawCookie) --> ok, user?
Eclat.health(port) --> ok, report?
Eclat.status(port) --> ok, report?
```

Small rites:

```luau
Eclat.filter({ WhitelistedInstances = {...}, Instances = {...} })
Eclat.replace(found, { { oldId = 1, newId = 2 } })
Eclat.hex("hello") --> "68656c6c6f"
Eclat.hexBuffer(buffer.fromstring("hi")) --> "6869"
Eclat.sanitize('  ".ROBLOSECURITY=tok"  ') --> "tok"
```

Pet names:

```luau
Eclat.liaison == Eclat.connect
Eclat.psalm == Eclat.reupload
Eclat.radiance == Eclat.stream
Eclat.vow == Eclat.importCookie
Eclat.spark == Eclat.hex
```

---

`--> ["the wire"]`

| verse | tongue |
|---|---|
| `GET /` | drink answers (`{oldId,newId}`), or `"done"` |
| `POST /reupload` | carry a pilgrimage of ids |
| `POST /upload` | carry one hex payload straight home |
| `POST /cookie` | import a hot cookie |
| `GET /health` | are we breathing? |
| `GET /status` | where walks the pilgrimage? |
| `GET /version` | names + numbers |

The engine kneels on `:8080`, with `:38073` lit for old pilgrims.

---

`--> ["vows"]`

- carry only what you own or hold the rights to.
- the cookie is never printed, never warned, never logged.
- enable HTTP requests in your place for the wire to sing
  (game settings → security → enable studio access to APIs is NOT this;
  the place needs HttpService access: Home → Game Settings → Security → Enable HTTP requests).

---

`--> ["read next"]`

```text
Examples/Boot.server.luau
Examples/HexUpload.server.luau
Validation/README.md
Validation/StudioChecklist.md
```
