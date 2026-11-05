# Example addon bundle

[Português](addon-bundle.pt-BR.md) · [Turnover example](turnover-addon.md)

Build one portable Harbour module for the project examples:

```powershell
./scripts/build-hbbridge-addons.ps1
```

The default artifact is `addons/examples/hbbridgeaddons.hrb`; pass `-Output` to
install it under the running server's configured `AddonRoot`. The bundle compiles
four maintained `.hb` sources together. It has one `Main` entry point and an
explicit, case-sensitive action selector:

```json
{"service":"ADDON.Execute","params":{"module":"examples/hbbridgeaddons.hrb","params":{"action":"sample","params":{}}}}
```

Available actions are `sample`, `benchmark`, `temporaryInsert` and `turnover`.
Each action receives its existing parameter object and returns its existing
response. A case-sensitive request-local hash maps approved action names to
HRB-local function symbols. `hb_ExecFromArray()` invokes the selected symbol
with the JSON parameters and call context; its argument array is required by
that native API. Add actions to the registry and include their source in the
bundle; client-supplied function names are never resolved. The bundle rejects
unknown actions and malformed envelopes. It invokes
nested services with the original call context, so their permissions remain in
force. Database credentials remain in server configuration. The client must
construct trusted SQL and application context when the selected example needs it.

The single bundle is the default for the temporary browse, benchmark and turnover
examples. The generic executor still accepts independently installed `.hb`,
`.prg` and `.hrb` modules with their original entry contract; existing dedicated
build scripts remain for compatibility and native regression fixtures. An HRB
can contain multiple Harbour functions, but independent addons need not share
one HRB or release lifecycle. The compiler includes the four source files in one
compilation unit and assigns their separate `Main` functions distinct names in
that unit. When extending the bundle, also avoid duplicate static helper names.

The benchmark client wraps parameters in the action envelope when its configured
module ends in `hbbridgeaddons.hrb`; an explicitly configured older independent
benchmark module retains the original direct parameter contract. Existing INI
values therefore continue to select their configured module; update the setting
when switching installations to the bundle.
