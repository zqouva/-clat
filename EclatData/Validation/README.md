# Éclat Validation

``--> [`what this is`]``

Small checks for the small pieces.
Run them in studio; silence is success.

``--> [`checks`]``

```text
Validation/
  HexValidation.server.luau     -- the hex translator, checked
  UplinkValidation.server.luau  -- retry · waitgroup · cookie sanitize · codes

  README.md
  StudioChecklist.md
```

``--> [`how`]``

1. Drop `Eclat` under `ServerStorage.Packages.Eclat`.
2. Drop a validation script under `ServerScriptService`.
3. Press play in studio. Read the output.
4. Every check prints `all checks pass` or asserts loudly.

``--> [`rules`]``

No check touches the network,
and none ever print a cookie.
