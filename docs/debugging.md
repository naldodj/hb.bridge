# Debugging: hbdebug first, optional HBDAP later

[Português](debugging.pt-BR.md) · [Documentation](README.md) · [Roadmap](../TODO.md#debugging-cross-cutting-work)

Native `hbdebug` is available in Harbour. A product/addon debug profile and
its integration acceptance remain pending: having the debugger in the
toolchain does not establish a working hbBridge debugging session.

## Native Harbour debugging

The initial development-console profile will use
[hbdebug](https://github.com/harbour/core/tree/master/src/debug) for
breakpoints, stepping, stack inspection and variables, using the same product
implementation as ordinary execution.

Compile Harbour sources with `-b`, link the debugger and retain accessible,
matching sources. This includes `.prg`/`.hb` sources compiled in memory by the
loader and `.hrb` modules prepared outside the server. The current
[build composition](../hbbridge.hbm) and `hb_compileBuf` call in
[the loader](../src/hb/addons/hbbridge.addon.hb) do not enable `-b`.
`hbmk2 -debug` controls native C debug information; Harbour's `-b` serves a
different purpose. See
[hbmk2](https://github.com/harbour/core/blob/master/utils/hbmk2/hbmk2.prg).

Initial acceptance must exercise one controlled call and worker: pause in a
handler and an addon, inspect their state and resume through the response.
Define the terminal/GT configuration, effects on RPC timeouts and resource
cleanup. Enable the development profile explicitly; system-service operation
must not require interactive debugging.

## Future HBDAP integration

**HBDAP** is a private experimental project, locally referenced as
`F:\GitHub\hbdap`, adapting Harbour debugging to the Debug Adapter Protocol
(DAP). The local path is a development reference, not a fixed installation
dependency. Native hbdebug remains the initial path; DAP can later serve IDE
and CLI clients.

The optional VS Code **Harbour DAP** extension is developed separately in
`hbdap-vscode-extension`, locally `F:\GitHub\hbdap-vscode-extension`. It
registers the `harbour-dap` debug type in `launch.json` and connects the editor
to a DAP-enabled runtime, directly or through an adapter according to the
selected mode. The intended flow is **VS Code → Harbour DAP extension →
HBDAP → hbdebug in hbBridge**. Other DAP clients can also use HBDAP.

The VSIX packages editor integration. The Harbour runtime, HBDAP library and
any mode-specific adapters are prepared separately. Pin compatible runtime
hooks/patches, revisions and toolchain; configure the executable and sources;
then validate launch/attach with an actual handler and addon. This remains
future hbBridge integration even where HBDAP and the extension have their own
tests.

The experimental HBDAP reference uses runtime hooks/patches and rebuilding.
Multithreaded debugging and the HRB load/unload lifecycle require specific
hbBridge acceptance. Basic DAP support does not prove worker control.

## Channels and runtime boundaries

Keep debugging traffic separate from Protheus/NETIO RPC and administration,
with explicit activation and local/controlled access. Server logs and output
must not corrupt DAP framing. An external development adapter remains optional
and preserves the single-product-executable design.

Validate breakpoints, stepping, stack, variables and disconnect against the
[roadmap criteria](../TODO.md#debugging-cross-cutting-work).
This work inspects Harbour execution in hbBridge. AdvPL/TLPP uses AppServer
debugging; C/Zig requires native symbols and a debugger compatible with the
toolchain. Call correlation helps trace these boundaries without promising
one stepping session across runtimes.
