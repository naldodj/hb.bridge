# FWWebEx HTTP table: validation confirmed

[Português](README.pt-BR.md) · [Consumer catalog](../../../../../examples/protheus/README.md) · [Acceptance](../../../../../docs/acceptance.md)

Validation of this example was confirmed on **2026-10-13**, supported by the
six screenshots below. FWWebEx displays the table and filters; Protheus prepares
the SQL and calls `HBBridgeHTTPClient`/`HBBridgeRPCDataSet` over HTTP.

The fixture contains **12 rows**. The SX5 view shows **11,764 entries**, pages
of 5/10 rows, search for `TIPOS DE IMPOSTOS` and an equality filter on
Description; both filtered views show **1 entry from 11,764**. The fixture
search for `Harbour` shows **1 entry from 12**. Its unfiltered view displays
`O'Brien`, `100%_done` and `<b>literal text</b>` as text.

## Run the consumers

Compile the complete `src/tlpp/` tree. The interactive entry points require
FWWebEx, its DataTable components and `FWWebEx.Tools.FWExampleTools` in the
RPO, plus a working Protheus UI and hbBridge HTTP/SQL configuration.

- `U_HBBridgeHTTPTable()` uses the constant fixture and `[hbBridge] SQLProfile`.
- `U_HBBridgeHTTPTableSX5()` selects the profile using Protheus `FWGetTopInfo()`;
  Protheus resolves `RetSQLName("SX5")`, `xFilial("SX5")` and deletion predicates.
- For explicit configuration, call
  `HBBridge.Examples.HBBridgeHTTPTableExample():Show(lUseSX5, cProfile, cURL, cToken, nTimeoutSeconds)`.
  Omitted HTTP settings read the active AppServer `[hbBridge]` section.

The profile must exist on hbBridge. HTTP credentials stay on the AppServer;
browser requests contain pagination, mapped field names and filter values.

This visual validation covers the demonstrated interactive views.
The separate `U_HBBridgeHTTPTableTest()` mock was validated on **2026-10-13
at 17:46:56 São Paulo**, thread **27708**: **71 checks, all PASS, zero failures**.
The 19 queued responses were consumed without unexpected calls, including
NUL rejection/preservation, failure recovery and missing-total handling.
See the [regression record](../../../../../docs/acceptance.md#http-table-regression-validation-on-2026-10-13).
`U_HBBridgeDataSetTest()` and `U_HBBridgeHelperTest()` have separate confirmed
validation at 17:56:23/17:56:45 on the same date: 67 checks/31 calls and 12 checks,
both OK. WIP D02 is complete; D03 tracks broader UTF-8/FLOAT integrity.
See the [active package](../../../../../WIP.md).

## SX5 evidence

Five-row page with the unfiltered total:

<img width="1350" height="646" alt="SX5 five-row page" src="https://github.com/user-attachments/assets/bcd459ee-7d93-42ec-9d18-26fddf9ee5e1" />

Global text search:

<img width="1353" height="643" alt="image" src="https://github.com/user-attachments/assets/6f646f52-16fe-474e-845d-bf38d68f5bcf" />

Ten-row page before applying the populated field filter:

<img width="1359" height="647" alt="image" src="https://github.com/user-attachments/assets/0554c5d3-f83a-41d8-af2e-b18667f68c80" />

Description equality filter:

<img width="1356" height="647" alt="image" src="https://github.com/user-attachments/assets/7f3b939e-49f0-440b-bf31-3a1dabff34fe" />

## Constant fixture evidence

Ten rows displayed from the 12-row fixture, including literal markup:

<img width="1350" height="642" alt="image" src="https://github.com/user-attachments/assets/4144767d-2048-4eff-870f-00c792c25b47" />

Global search for Harbour:

<img width="1349" height="631" alt="image" src="https://github.com/user-attachments/assets/6935fb76-6201-4edb-89a9-566a9f7cf2a5" />
