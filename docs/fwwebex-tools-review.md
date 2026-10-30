# FWWebEx utility review

[Português](fwwebex-tools-review.pt-BR.md) · [Native presentation](native-presentation.md) · [WIP](../WIP.md)

Static review recorded on 2026-10-29 of the supplied FWWebEx utilities and
their overlap with hbBridge. This records candidates and constraints; it
does not implement APIs, add a FWWebEx core dependency or establish runtime
acceptance or a measured performance improvement.

## Scope and decisions

The reference sources belong to `fw.webex/src/fw.webex/core/tools/` in the
FWWebEx repository. All seven requested files were reviewed:

| Reference | Decision for hbBridge |
| --- | --- |
| `fw.webex.jsonobject.tools.tlpp` | First candidate: a narrow, recursive JSON clone, without generic object reflection. Keep the current transport codec. |
| `fw.webex.jsonobject.clone.tlpp` | The separate forwarding class adds no behavior; prefer one utility API. |
| `fw.webex.jsonobject.merge.tlpp` | Consider only after defining depth, array, NULL and mutation policies. The wrapper alone adds no behavior. |
| `fw.webex.jsonobject.flatten.tlpp` | Possible diagnostic feature; the supplied format is unsuitable for lossless generic contracts. |
| `fw.webex.stopwatch.tlpp` | Consider a small elapsed-time/named-phase helper built on the existing `HBBridgeTime`. |
| `fw.webex.class.base.tlpp` | Do not introduce common core inheritance or generic resource cloning. |
| `fw.webex.array.tools.tlpp` | Reuse selected operations only at required native positional APIs; keep records and lookups keyed. |

## First candidate: defensive JSON clone

`HBBridgeRPCDataSet:Header()`, `FieldInfo()`, `GetRow()` and `GetRows()`,
`HBBridgeNativeTable` schema snapshots and the presentation builder's
`TableCopy()` currently clone through `HBBridgeJSON:Encode()` and `Parse()`.
A direct recursive clone could remove this extra serialization/parsing and
its intermediate JSON string. The benefit must be measured before replacing
accepted paths; no speedup is asserted here.

The reference `CloneJSON()` reaches recursive copying through temporary
`JSONObjectTools` instances and `ClassBase` reflection/macros. hbBridge needs
only JSON values: enumerate JSONObject keys once, recursively copy nested
containers and copy scalar values without formatting. Arrays remain valid
where the JSON/native API requires them; they do not replace keyed rows.

The proposed contract must preserve absent versus present-NULL properties,
UTF-8 bytes, embedded NUL, exact decimal/int64 strings and the numeric value
already held by the SDK. Cloning must not decode text, change SETs, infer
rounding or copy sockets/connections. Define rejection of unsupported native
objects/blocks and behavior for cycles or excessive recursion before exposing
the API. The caller owns the independent result.

Targeted regressions must cover:

- Empty and nested objects/arrays, mixed arrays and arrays within arrays.
- Missing keys versus NULL; empty text, UTF-8 and NUL at every string position.
- Exact numeric strings, small/large numeric values and SET independence.
- Mutation of each container in the result without changing the source.
- Release of either source or result without invalidating the other.
- Explicit failure for unsupported values/cycles, with partial allocations cleaned.
- Equivalent results and elapsed/allocation measurements against existing snapshots.

## Merge and flatten constraints

The supplied `MergeJSON()` replaces top-level values; it does not recursively
combine the properties of objects already in the target. Its object branch
tests `vValue[j]` outside the array loop instead of `vValue`. Arrays nested
inside arrays are assigned by reference. These are reasons to adapt the idea,
not copy it as an accepted deep-merge implementation.

Any future merge must define whether it mutates the target, recursively
combines objects, replaces or combines arrays, treats NULL as a value or a
deletion, and handles incompatible types. Configuration/schema validation
still applies after a merge; merging must not bypass allowed-property checks.

Flatten concatenates keys using dots and brackets without an escaping
contract. For example, the literal key `a.b` collides with nested `a`/`b`.
UnFlatten interprets strings such as `__$O:0` and `__$A:0` as containers, so
ordinary text can change type. Nested-array values can also remain shared.
Keep this outside the RPC/HTTP contract. A future reversible format would
need escaped paths, distinct container metadata, collision handling and
roundtrip tests, including empty containers and literal marker text.

`ToJSObjectString()` is JavaScript source generation: it emits unquoted keys,
does not escape ordinary array strings and can insert functions using a
reserved token. This belongs to trusted UI construction, not JSON transport.
Keep `HBBridgeJSON` as the Encode/Parse boundary.

## Timing, reflection and native arrays

The useful StopWatch idea is elapsed measurement with named phases. An
hbBridge helper should delegate clock reads to the existing `HBBridgeTime`,
keep state per instance and report explicit operation outcomes separately
from durations. It must not replace request budgets or the benchmark's
existing sample, warmup, validation and failure rules.

The supplied implementation also needs adaptation:

- `StartWithDate()` stores an epoch-based time, while ordinary `Stop()` and
  running elapsed queries use normalized `TimeCounter()`. Mixing those modes
  subtracts values from different clock domains.
- Subtracting the sum of child durations from parent duration double-counts
  overlapping phases; a zero clamp does not establish exclusive time.
- `SuccessRate` is inferred from durations exceeding a timeout threshold;
  this does not prove operation success or failure.
- The mutable static ID counter must not become shared unsynchronized state
  if ported. Use instance/worker ownership or a UUID appropriate to the need.

`ClassBase` adds member enumeration, macros and generic object construction.
Its complex-data clone deliberately retains objects that do not meet its
clone protocol. That cannot promise independent ownership of arbitrary
resources. Explicit copies of hbBridge value contracts are more appropriate
than cloning clients, datasets, sockets, connections or UI objects.

`ArrayTools:Clone()` recursively copies subarrays, but retains JSON/object
references. `MergeUnique()` repeatedly performs linear `Contains()` searches,
which can yield quadratic comparison cost as the result grows. `MergeDeep()`
calls `Merge()` for paired subarrays, not recursively `MergeDeep()`; its
behavior must not be presented as a recursive positional merge. Consider
only small, demonstrated native-array needs and preserve JSON/hash maps for
keyed records, metadata and membership checks where suitable.

## Provenance and next step

Several reference headers declare release to the public domain and identify
the DNA-Tech or `naldodj-hb-flatten-json` origins. The FWWebEx repository also
contains its MIT license. Preserve applicable source notices and provenance
if code is copied later; no source was copied as part of this review.

The next implementation candidate is the narrow JSON clone with the targeted
regressions above. Timing phases follow only for a concrete diagnostic need;
merge/flatten and generic array operations remain deferred. Continue the
active presentation work through [WIP](../WIP.md).
