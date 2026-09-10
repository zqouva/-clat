# Éclat Studio Checklist

``--> [`before the run`]``

- [ ] The engine runs and prints its magenta banner (`cargo run --release`).
- [ ] `GET http://127.0.0.1:8080/health` answers `{"status":"online",...}`.
- [ ] The place is published (`game.PlaceId ~= 0`).
- [ ] HTTP requests are enabled (Game Settings → Security).
- [ ] The plugin's `EclatData` module (renamed to `Eclat`) lives at `ServerStorage.Packages.Eclat`.
- [ ] The plugin/place has script injection permission (for id rewriting).
- [ ] You own (or hold the rights to) every asset you will upload.

``--> [`the checks`]``

- [ ] `HexValidation.server.luau` prints `all checks pass`.
- [ ] `UplinkValidation.server.luau` prints `all checks pass`.
- [ ] `Boot.server.luau` reuploads one animation, end to end.
- [ ] `HexUpload.server.luau` sends one payload via `POST /upload`.
- [ ] A tired cookie pauses the job and `POST /cookie` resumes it.

``--> [`after`]``

- [ ] Old ids in scripts/values/animations/sounds/meshes point at new ones.
- [ ] MeshParts were rebuilt with properties, attributes, tags, children, joints.
- [ ] `Output_<type>_<millis>.json` holds the answers (when `exportJson`).
- [ ] No cookie was printed, pasted, or committed anywhere.
