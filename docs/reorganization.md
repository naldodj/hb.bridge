# Source reorganization and validation

[Português (Brasil)](reorganization.pt-BR.md)

On 2026-10-01, the intended structure was applied to the existing implementation.
The prior reference commit is `b45595b24edf3002d80df69f9a412672173b5af0`.
This record distinguishes that structural baseline from subsequent product
milestones and the current naming/build reorganization.

## Responsibility map

| Historical source | Current component | Responsibility |
| --- | --- | --- |
| `src/hb/server/hbbridgenetio.prg` — Main | [host/hbbridgemain.prg](../src/hb/host/hbbridgemain.prg) | Entry, options, console lifecycle. |
| Same file — receive/send | [Protheus framing](../src/hb/transports/protheus/hbbridgeframing.prg) | Framing/compression. |
| `src/hb/server/mt_hbbridgenetio.prg` | [Protheus server](../src/hb/transports/protheus/hbbridgenetio.prg) | Listener, workers, shutdown. |
| `src/hb/dispatcher/hbbridgedispatcher.prg` | [core dispatcher](../src/hb/core/hbbridgedispatcher.prg) | Registry/dispatch/validation; native values since Milestone 1. |
| Service responses inside dispatcher | [builtin services](../src/hb/services/hbbridgeservices.prg) | Health/Echo/ADDON and discovery. |
| C block inside addon loader | [C/Zig bridge](../src/c/hbbridgezig.c) | Harbour API and Zig ABI. |
| `tests/harbour/` | [integration suite](../tests/integration/harbour/hbbridgeservertest.prg) | MT suite and fixtures. |
| `tests/protheus/` | [TLPP tests](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp) | All Protheus sources beneath the compilable TLPP tree. |

Loader, telemetry, TLPP client, Zig library, sample addon and configuration
remain in their own areas. No duplicate active server/MVP implementation exists.
[hbbridge.hbm](../hbbridge.hbm) centralizes components/flags;
[hbbridge.hbp](../hbbridge.hbp) adds the product entry, and
[the test project](../tests/integration/harbour/hbbridgeservertest.hbp) its test entry.
[The minimal example](../examples/mvp/README.md) uses the product binary.

## Historical structural validation

Reference environment: Windows, Harbour `3.2.1dev (r2608271822)` from hb_compile's
Zig profile, Zig `0.16.0`. The prior source was built independently from Git
in a temporary directory.

| Run | Result | Interpretation |
| --- | --- | --- |
| Unadjusted original suite | 44 checks, 35 failures; missing fixtures caused skips. | Helper used `0.0.0.0` as a client destination. |
| Prior product, normalized loopback/HRB test calls and prepared fixtures | 72 checks, zero failures, no skips. | Functional baseline, without changing prior product sources. |
| Reorganized components and expanded suite | 74 checks, zero failures, no skips. | Retained 72 checks plus extracted C-bridge Health and shared PRG addon compilation. |
| Reorganized executable | Build passed; help exited 0, invalid option exited 1. | Validated entry/composition. |

Coverage included both historical signatures, concurrency, malformed requests,
failed HRB, per-load static isolation, worker capacity and controlled stop.
The runner creates isolated fixtures and `tmp/tests-*/results.log` without
replacing the canonical product. TLPP was only moved in that structural run;
later AppServer acceptance is recorded in [acceptance](acceptance.md).
Interactive debugging was not tested.

## Current naming and build organization

Own sources use lowercase English filenames with the `hbbridge` prefix where
they identify a product component. TLPP class/file pairs are:
`HBBridgeClient`/`hbbridgeclient.tlpp`,
`HBBridgeConfig`/`hbbridgeconfig.tlpp`,
`HBBridgeTime`/`hbbridgetime.tlpp`,
`HBBridgeRPCDataSet`/`hbbridgerpcdataset.tlpp`.
Classes retain PascalCase by the owner's explicit decision; methods/functions
use lowercase, with native/public API exceptions documented in [standards](standards.md).

Harbour counterparts follow the same basename convention; extensions identify
the source language. Commit tools move from `bin/` to `.hbcommit/`.
Managed dependency bootstrap builds the project's own Harbour/hbrun rather than
depending on an embedded `bin/harbour` or a fixed external checkout.
English documentation has preserved `.pt-BR` counterparts.
See [dependencies](dependencies.md) and [the roadmap](../TODO.md).

## Scope of evidence

The historical structural step retained bind, signatures, JSON/compression,
ports and results. [Milestone 1](milestone1.md) added native registry/values,
NETIO/admin, configuration and dedicated tests.
[Milestone 2](milestone2-framing.md) replaced proof-of-concept limits and corrected
TCP gzip handling. [Milestone 3](milestone3-sql.md) added SQL/pages.
System-service integration, TLPP VF facade, debug profiles and negotiated
logical streams remain pending. Historical counts do not certify later changes;
new source/build naming requires its own build and regression run.
