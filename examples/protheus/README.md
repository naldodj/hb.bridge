# Protheus consumers and examples

[Português](README.pt-BR.md) · [Tests](../../tests/README.md) · [Dataset](../../docs/dataset.md)

The examples remain under `src/tlpp/tests/protheus/` so one recursive TLPP
compilation includes the product classes and their consumers. Each test group
has its own dotted directory; this guide does not duplicate those sources.

| Entry | Purpose | Requirements |
| --- | --- | --- |
| `U_HBBridgeConfigTest` | AppServer client configuration checks. | Active AppServer INI. |
| `U_HBBridgeConnectionTest` | Clock, Health, ADDON and exact Echo checks. | Running hbBridge TCP endpoint and addon fixture. |
| `U_HBBridgeDataSetTest` | Metadata, totals, profile changes and page traversal. | Mock client only; expected 67 checks/31 calls, runtime acceptance pending. |
| `U_HBBridgeHelperTest` | SQL aliasing, replacement and filter-expression checks. | No connection or ERP reads; expected 12 checks, runtime acceptance pending. |
| `U_HBBridgeQueryTest`, `U_HBBridgeQueryTestSQLite`, `U_HBBridgeQueryTestTopInfo` | Constant query/page fixture. | Explicit remote SQL profile; TopInfo resolves its alias on Protheus. |
| `U_HBBridgeHTTPTest`, `U_HBBridgeHTTPTestMSSQL`, `U_HBBridgeHTTPTestSQLite` | HTTP services and paginated SQL. | Enabled HTTP endpoint, client token and configured profile. |
| `U_HBBridgeBrowseDataTestSRA`, `U_HBBridgeBrowseDataTestSX5` | Interactive native browse, seek/filter and record view. | Protheus UI, dictionary/context and the example tables/profile. |

## Dataset consumer

```advpl
oDataSet := HBBridge.RDD.HBBridgeRPCDataSet():New(oClient)
oDataSet:SetAliasProfile(cProfile)
if oDataSet:OpenPage(cSQL, 1, 20, cOrderBy)
    while oDataSet:MoreToRead()
        xValue := oDataSet:FieldGet("NAME")
        oDataSet:Skip()
    enddo
    if !Empty(oDataSet:ErrorCode())
        // Handle a failed page request separately from normal EOF.
    endif
endif
oDataSet:Close()
```

The profile is an opaque, case-sensitive server key. `SetAliasProfile()` is
explicit configuration; `OpenSQL(cSQL[, jPage])` and `OpenPage()` no longer
take it as the first argument. The caller supplies projected field names and
a deterministic order. Totals require a separate count per page and are not
a database snapshot. See the dataset guide for ownership and unknown totals.

## Interactive browse

Sources are in [hbbridge.browse.data.test](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.tlpp),
with [SRA](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.sra.tlpp)
and [SX5](../../src/tlpp/tests/protheus/hbbridge.browse.data.test/hbbridge.browse.data.test.sx5.tlpp)
parameters. These are local ERP examples, not generic server defaults. Replace
their company/branch, physical SQL tables and ordering for your installation
on the Protheus side. `FWGetTopInfo()` chooses an example profile alias; that
exact key must exist on hbBridge.

`HBBridge.Client.HBBridgeBrowseData` resolves SX3 titles/pictures/types on
Protheus and adapts a page to FWBrowse's required array interface. The helper
copies row objects so releasing the JSON root does not invalidate displayed
rows. Field order follows header positions. A failed fetch retains displayed
rows and reports the dataset error; its failed dataset must be refreshed
before continuing navigation.

Filtering currently accepts caller SQL with an existing WHERE and without a
trailing ORDER BY/semicolon. It appends a predicate; it is not a general SQL
parser or parameter-binding API. `PrefixQryAlias()` preserves quoted text and
comments but does not resolve joins or ERP ownership. These presentation
helpers do not add business rules to the Harbour server.

The query test defaults to constant fixtures. Its optional fifth argument,
`lRunERPExamples := .T.`, explicitly enables the local SX5/SRA/SX3 examples
and their field output. Browse examples are operator-driven; they are not
executed by the Harbour regression or pure TLPP mock tests.

## Compilation and acceptance

Use [build-totvs.cmd](../../scripts/build-totvs.cmd) with your vendor includes.
It generates an explicit recursive `.tlpp` list, avoiding dotted directories
being interpreted as source files by the AppServer directory expander.
The local operator workflow requires an elevated terminal and the configured
TOTVS stop/start scripts, with restart attempted after compiler failure too.
The temporary `__rpo-legacy-cleanup` module only replaces an obsolete RPO
class module; it is not a parallel product implementation.

Compile success does not accept UI interactions. Exercise page boundaries,
empty/error results, text/numeric/date seek, quotes in filters and repeated
open/close in the actual AppServer. [Acceptance](../../docs/acceptance.md)
distinguishes native runs, compilation and operator results. UTF-8/FLOAT and
encrypted credential corrections remain in [WIP](../../WIP.md).
