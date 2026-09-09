# Éclat Studio Checklist

`--> ["before the pilgrimage"]`

- [ ] The engine runs and prints its magenta psalm (`cargo run --release`).
- [ ] `GET http://127.0.0.1:8080/health` answers `{"status":"online",...}`.
- [ ] The place is published (`game.PlaceId ~= 0`).
- [ ] HTTP requests are enabled (Game Settings → Security).
- [ ] `Eclat` lives at `ServerStorage.Packages.Eclat`.
- [ ] The plugin/place has script injection permission (for id rewriting).
- [ ] You own (or hold the rights to) every asset you will carry.

`--> ["the rites"]`

- [ ] `HexValidation.server.luau` prints `all verses true`.
- [ ] `UplinkValidation.server.luau` prints `all verses true`.
- [ ] `Boot.server.luau` carries one animation home, end to end.
- [ ] `HexUpload.server.luau` streams one payload via `POST /upload`.
- [ ] A tired cookie pauses (vigil) and `POST /cookie` resumes it.

`--> ["after"]`

- [ ] Old ids in scripts/values/animations/sounds/meshes point at new homes.
- [ ] MeshParts were reborn with properties, attributes, tags, children, joints.
- [ ] `Output_<type>_<millis>.json` chronicles the answers (when `exportJson`).
- [ ] No cookie was printed, pasted, or committed anywhere.
