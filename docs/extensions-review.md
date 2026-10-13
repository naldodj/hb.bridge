# SQLRDD, JavaScript and agent extensions

[Português](extensions-review.pt-BR.md) · [Roadmap](../TODO.md) · [Active package](../WIP.md)

Reviewed on 2026-10-12 from `hbBridge_Braimstorming.txt` and the
primary sources below. These are future extension decisions, not delivered
services or dependencies. Package 001 remains open; its dataset, encoding and
numeric integrity work comes first.

| Reference | Assessment | Proposed use |
| --- | --- | --- |
| xHarbour-SQLRDD | Useful RDD design reference; adoption needs a concrete gap and source/license review. | Compare catalog/index/type/seek behavior against existing SQLMIX; preserve explicit caller metadata. |
| Duktape | Feasible optional C engine. Engine embedding alone does not certify isolation or deadlines. | Registered JavaScript modules with explicit inputs and restricted host bindings. |
| CCHarbour | Candidate for an optional agent addon, not a replacement for the service core. | Explicit tools, asynchronous jobs and a configured model provider. |

## xHarbour-SQLRDD

The supplied [topconn.prg](https://github.com/xHarbour-org/xharbour/blob/main/xHarbourBuilder/xHarbour-SQLRDD/samples/topconn.prg)
is a SQLRDD compatibility sample using SQL catalog/index operations and xBase
navigation. It does not demonstrate an hbBridge connection to the DBAccess
wire protocol. Its header also reserves rights; inspect each source's terms
before importing code from the [SQLRDD tree](https://github.com/xHarbour-org/xharbour/tree/main/xHarbourBuilder/xHarbour-SQLRDD).

Keep SQLMIX/SDDODBC/SDDSQLITE3 as the implemented route. An optional connector
must justify a capability the current route lacks and pass type/null/encoding,
seek, locking, cleanup and Windows/Linux checks. Protheus continues resolving
SX3/TOP_FIELD, physical tables, company/branch/tenant and deletion rules.
Neither a compatible RDD API nor catalog discovery proves DBAccess business
semantics. Native DBF/NETIO remains a separate route.

## Duktape

[Duktape](https://github.com/svaarala/duktape) embeds through C sources, uses
the MIT license and principally implements ES5/5.1 with partial later features.
Pin a released distribution; its master branch is changing incompatibly for
3.x. Node.js is not needed to execute the packaged embedded engine.

Our proposed addon accepts a configured module ID/version and JSON/native
parameters, with a registry permission and a defined result. Prefer deployed
modules over arbitrary source in network requests. Protheus owns the rule and
supplies its context; hbBridge executes that supplied module generically.
Declare decimal representation explicitly, since JavaScript numbers cannot
replace the pending exact-numeric contract.

The [sandboxing guide](https://duktape.org/guide.html#sandboxing) treats C
bindings as trusted and describes incomplete sandbox support in 2.x. Therefore
do not advertise a secure sandbox merely because a separate heap exists.
Our acceptance must verify allocator budgets, execution-time checks,
cancellation, denied file/network/process bindings, worker state reset and
cleanup. A script timeout cannot interrupt a blocking host binding by itself;
untrusted scripts may require a separate worker process. No engine or service
has been added in this review.

## CCHarbour

[CCHarbour](https://github.com/FiveTechSoft/CCHarbour) describes an embeddable
Harbour assistant with background subagents and an approximately 2 MB console
binary. That size is an upstream claim about its executable, not hbBridge,
model weights or total memory. Its default backend is a remote API; local
[Ollama support is experimental](https://github.com/FiveTechSoft/CCHarbour/blob/master/README.md#running-locally-with-ollama-experimental)
and depends on model/tool-call compatibility and hardware. Its
[MIT license](https://github.com/FiveTechSoft/CCHarbour/blob/master/LICENSE)
does not establish the license of every transitive dependency.

Proposed integration: an optional addon with approved tools and job/status/
cancel contracts, explicit inputs and separately provisioned provider secrets.
Keep task state request/job-owned, with synchronized shared resources. Existing
SQL calls remain serialized by the SQL mutex; background threads do not prove
parallel database execution.

A local-model configuration must explicitly control endpoints, tool access,
logs and any remote fallback. Model output is not authorization to execute SQL,
write ERP data or start a process. Start acceptance with synthetic read-only
tools; real ERP context and any mutations remain governed by the Protheus
caller. This is an integration design, not an installed agent or a privacy,
performance or binary-size guarantee.

## Delivery order

Complete the current dataset/type/encoding and relevant security acceptance.
Then evaluate SQLRDD source reuse, a bounded Duktape module package and an
optional CCHarbour job package separately. Record pinned sources, dependencies,
license provenance, exposed services and attributable tests before advertising
each capability. This review neither installs these projects nor changes WIP's
completion criteria.
