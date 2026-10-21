/* Released to Public Domain. */
#include "hbhrb.ch"

PROCEDURE BenchmarkAddonTests( cAddonRoot )

    LOCAL cJSON, cMode

    LOCAL hHRB, hState, hRegistry, hContext, hRestricted, hParams, hResult, hSeries, hInvalid

    LOCAL nFailures, nChecks, nCalls

    LOCAL xValue

    nFailures := 0
    nChecks := 0
    hState := { "calls" => 0, "rows" => 17, "size" => 7, "mode" => "success", ;
        "paramsValid" => .T., "failAt" => 0, "password" => "fixture-private-password" }
    hRegistry := BenchmarkAddonRegistry( hState )

    hb_default( @cAddonRoot, hb_cwd() + "addons" )
    hContext := HBBridgeContext( "benchmark-addon-test", cAddonRoot, hState )
    BenchmarkAddonAssert( File( hb_DirSepAdd( cAddonRoot ) + "hbbridgebenchmarkaddon.hrb" ), ;
        "compiled benchmark HRB exists", @nFailures, @nChecks )
    BenchmarkAddonAssert( File( hb_DirSepAdd( cAddonRoot ) + "hbbridgesampleaddon.hrb" ), ;
        "compiled original one-argument HRB exists", @nFailures, @nChecks )

    hParams := BenchmarkAddonParams()
    hResult := BenchmarkAddonRun( hRegistry, hContext, hParams )
    BenchmarkAddonAssert( hb_HGetDef( hResult, "success", .F. ), ;
        "all addon traversals pass", @nFailures, @nChecks )
    IF ! hb_HHasKey( hResult, "series" )
        ? "Benchmark addon checks:", nChecks, "failures:", nFailures
        ErrorLevel( 1 )
        RETURN
    ENDIF
    hSeries := hResult[ "series" ]
    BenchmarkAddonAssert( hState[ "calls" ] == 9 .AND. hState[ "paramsValid" ], ;
        "three complete paged traversals issue nine checked queries", @nFailures, @nChecks )
    BenchmarkAddonAssert( hResult[ "fixture" ] == "m08.constant.v1" .AND. ;
        hResult[ "schemaVersion" ] == 1 .AND. hResult[ "profile" ] == "opaque/profile", ;
        "fixture identity and opaque profile are preserved", @nFailures, @nChecks )
    BenchmarkAddonAssert( hResult[ "rowsPerIteration" ] == 17 .AND. hResult[ "pageSize" ] == 7 .AND. ;
        hResult[ "iterations" ] == 2 .AND. hResult[ "warmupIterations" ] == 1, ;
        "report records requested workload", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "completedIterations" ] == 2 .AND. hSeries[ "warmupCompleted" ] == 1, ;
        "warmup and measured traversal counts remain separate", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "measuredCalls" ] == 6 .AND. hSeries[ "measuredRows" ] == 34, ;
        "measured counters exclude warmup", @nFailures, @nChecks )
    BenchmarkAddonAssert( Len( hSeries[ "samples" ] ) == 2 .AND. Len( hSeries[ "warmupSamples" ] ) == 1, ;
        "warmup and measurement samples have separate keyed maps", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "samples" ][ "1" ][ "rowsRead" ] == 17 .AND. ;
        hSeries[ "samples" ][ "1" ][ "pagesRead" ] == 3 .AND. ;
        hSeries[ "samples" ][ "2" ][ "rowsRead" ] == 17 .AND. ;
        hSeries[ "samples" ][ "2" ][ "pagesRead" ] == 3, ;
        "partial final pages preserve every row", @nFailures, @nChecks )
    BenchmarkAddonAssert( HB_ISNUMERIC( hSeries[ "avgMs" ] ) .AND. hSeries[ "avgMs" ] >= 0 .AND. ;
        hSeries[ "avgMs" ] == hSeries[ "totalMs" ] / 2 .AND. ;
        hSeries[ "minMs" ] <= hSeries[ "avgMs" ] .AND. hSeries[ "maxMs" ] >= hSeries[ "avgMs" ], ;
        "timing statistics use only successful measured traversals", @nFailures, @nChecks )
    cJSON := hb_jsonEncode( hResult )
    BenchmarkAddonAssert( !( '"header":' $ cJSON ) .AND. !( '"rows":' $ cJSON ) .AND. ;
        !( "fixture-private-password" $ cJSON ) .AND. !( '"registry":' $ cJSON ) .AND. ;
        !( "SELECT ID" $ cJSON ), "response omits rows, headers, SQL and native credentials", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "serverRunElapsedMs" ] >= 0 .AND. ;
        hSeries[ "clock" ] == "HBBridgeMonotonicMs" .AND. ;
        "excludes transport and HRB loading" $ hSeries[ "timingScope" ], ;
        "server timing and its excluded work remain explicit", @nFailures, @nChecks )

    hState[ "calls" ] := 0
    hState[ "rows" ] := 9
    hState[ "size" ] := 4
    hParams[ "rows" ] := 9
    hParams[ "pageSize" ] := 4
    hParams[ "iterations" ] := 1
    hParams[ "warmup" ] := 0
    hResult := BenchmarkAddonRun( hRegistry, hContext, hParams )
    BenchmarkAddonAssert( hResult[ "success" ] .AND. hState[ "calls" ] == 3 .AND. ;
        hResult[ "series" ][ "measuredRows" ] == 9 .AND. hResult[ "series" ][ "measuredCalls" ] == 3 .AND. ;
        Len( hResult[ "series" ][ "samples" ] ) == 1 .AND. ;
        Len( hResult[ "series" ][ "warmupSamples" ] ) == 0, ;
        "reloaded HRB has no preserved counters or prior samples", @nFailures, @nChecks )

    hState[ "calls" ] := 0
    hState[ "rows" ] := 17
    hState[ "size" ] := 7
    hParams := BenchmarkAddonParams()
    hParams[ "profile" ] := "unknown/profile"
    hResult := BenchmarkAddonRun( hRegistry, hContext, hParams )
    hSeries := hResult[ "series" ]
    BenchmarkAddonAssert( !hResult[ "success" ] .AND. hState[ "calls" ] == 1 .AND. ;
        hSeries[ "failureCategory" ] == "WARMUP_FAILED" .AND. ;
        hSeries[ "failurePhase" ] == "warmup" .AND. hSeries[ "failureIteration" ] == 1, ;
        "unknown profile stops at the first warmup query", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "warmupSamples" ][ "1" ][ "serviceCode" ] == "PROFILE_NOT_FOUND" .AND. ;
        hSeries[ "warmupSamples" ][ "1" ][ "failedPage" ] == 1 .AND. ;
        hSeries[ "warmupSamples" ][ "1" ][ "failureCategory" ] == "QUERY_FAILED", ;
        "failure preserves safe service code and page", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "avgMs" ] == NIL .AND. hSeries[ "totalMs" ] == NIL .AND. ;
        hSeries[ "minMs" ] == NIL .AND. hSeries[ "maxMs" ] == NIL .AND. ;
        hSeries[ "measuredRows" ] == 0 .AND. hSeries[ "completedIterations" ] == 0, ;
        "failed warmup cannot become a synthetic zero average", @nFailures, @nChecks )

    hParams := BenchmarkAddonParams()
    hParams[ "warmup" ] := 0
    hParams[ "iterations" ] := 2
    hState[ "calls" ] := 0
    hState[ "failAt" ] := 4
    hResult := BenchmarkAddonRun( hRegistry, hContext, hParams )
    hSeries := hResult[ "series" ]
    BenchmarkAddonAssert( !hResult[ "success" ] .AND. hState[ "calls" ] == 4 .AND. ;
        hSeries[ "completedIterations" ] == 1 .AND. hSeries[ "measuredCalls" ] == 3 .AND. ;
        hSeries[ "measuredRows" ] == 17 .AND. HB_ISNUMERIC( hSeries[ "avgMs" ] ), ;
        "later query failure preserves only completed measured totals", @nFailures, @nChecks )
    BenchmarkAddonAssert( hSeries[ "failurePhase" ] == "measured" .AND. hSeries[ "failureIteration" ] == 2 .AND. ;
        hSeries[ "samples" ][ "2" ][ "serviceCode" ] == "QUERY_FAILED", ;
        "failed measured iteration keeps its index and safe diagnostic", @nFailures, @nChecks )
    hState[ "failAt" ] := 0

    // These hashes model fault categories; no native database or network is used.
    FOR EACH cMode IN { "metadata" => "metadata", "page" => "page", "value" => "value", "type" => "type" }
        hState[ "mode" ] := cMode
        hState[ "calls" ] := 0
        hResult := BenchmarkAddonRun( hRegistry, hContext, hParams )
        hSeries := hResult[ "series" ]
        BenchmarkAddonAssert( !hResult[ "success" ] .AND. hState[ "calls" ] == 1 .AND. ;
            hSeries[ "avgMs" ] == NIL .AND. hSeries[ "samples" ][ "1" ][ "failedPage" ] == 1, ;
            "invalid " + cMode + " fixture is rejected before comparison", @nFailures, @nChecks )
    NEXT
    hState[ "mode" ] := "success"

    hParams := BenchmarkAddonParams()
    /* JSON array values deliberately exercise the external parameter contract. */
    FOR EACH xValue IN { "text" => "17", "logical" => .T., "null" => NIL, "array" => {}, ;
        "object" => {=>}, "zero" => 0, "negative" => -1, "fractional" => 1.5, "large" => 100001 }
        hInvalid := hb_HClone( hParams )
        hInvalid[ "rows" ] := xValue
        nCalls := hState[ "calls" ]
        hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
        BenchmarkAddonAssert( hb_HGetDef( hResult, "code", "" ) == "INVALID_PARAMS" .AND. ;
            hState[ "calls" ] == nCalls, "invalid row parameter rejected before query", @nFailures, @nChecks )
    NEXT
    hInvalid := hb_HClone( hParams )
    hInvalid[ "pageSize" ] := 0
    hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "zero page size rejected", @nFailures, @nChecks )
    hInvalid := hb_HClone( hParams )
    hInvalid[ "warmup" ] := -1
    hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "negative warmup rejected", @nFailures, @nChecks )
    hInvalid := hb_HClone( hParams )
    hInvalid[ "iterations" ] := 0
    hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "zero iteration count rejected", @nFailures, @nChecks )
    hInvalid := hb_HClone( hParams )
    hb_HDel( hInvalid, "profile" )
    hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "missing parameter rejected", @nFailures, @nChecks )
    hInvalid := hb_HClone( hParams )
    hInvalid[ "sql" ] := "SELECT private-query"
    hResult := BenchmarkAddonRun( hRegistry, hContext, hInvalid )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "extra SQL parameter rejected", @nFailures, @nChecks )

    hHRB := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, hb_DirSepAdd( cAddonRoot ) + "hbbridgebenchmarkaddon.hrb" )
    hb_jsonDecode( hb_hrbDo( hHRB, hb_jsonEncode( hParams ) ), @hResult )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "missing native context rejected", @nFailures, @nChecks )
    hb_jsonDecode( hb_hrbDo( hHRB, hb_jsonEncode( hParams ), {=>} ), @hResult )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_CONTEXT", "context without registry rejected", @nFailures, @nChecks )
    hb_jsonDecode( hb_hrbDo( hHRB, hb_jsonEncode( hParams ), "invalid-context" ), @hResult )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "invalid native context type rejected", @nFailures, @nChecks )
    hb_jsonDecode( hb_hrbDo( hHRB, "{", hContext ), @hResult )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "malformed addon JSON rejected", @nFailures, @nChecks )
    hb_jsonDecode( hb_hrbDo( hHRB, "[]", hContext ), @hResult )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_PARAMS", "array addon parameters rejected", @nFailures, @nChecks )
    hb_hrbUnload( hHRB )

    hRestricted := HBBridgeContext( "restricted", cAddonRoot, hState )
    /* Permissions are the native dispatcher array contract, not a record map. */
    hRestricted[ "permissions" ] := { "addon.execute" }
    nCalls := hState[ "calls" ]
    hResult := BenchmarkAddonRun( hRegistry, hRestricted, hParams )
    BenchmarkAddonAssert( !hResult[ "success" ] .AND. hState[ "calls" ] == nCalls .AND. ;
        hResult[ "series" ][ "warmupSamples" ][ "1" ][ "serviceCode" ] == "FORBIDDEN", ;
        "addon inherits caller query denial without escalating permission", @nFailures, @nChecks )
    BenchmarkAddonAssert( Len( hRestricted[ "permissions" ] ) == 1 .AND. ;
        hRestricted[ "permissions" ][ 1 ] == "addon.execute", ;
        "nested dispatch does not mutate caller permissions", @nFailures, @nChecks )
    hRestricted[ "permissions" ] := { "service.call" }
    hResult := BenchmarkAddonRun( hRegistry, hRestricted, hParams )
    BenchmarkAddonAssert( hResult[ "code" ] == "FORBIDDEN" .AND. hState[ "calls" ] == nCalls, ;
        "caller addon denial remains enforced before HRB execution", @nFailures, @nChecks )

    hResult := HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
        { "module" => "hbbridgesampleaddon.hrb", "params" => {=>} }, hContext )
    BenchmarkAddonAssert( hb_HGetDef( hResult, "success", .F. ) .AND. ;
        hb_HHasKey( hResult, "addon_msg" ), "original one-argument addon remains compatible", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
        { "module" => "../outside.hrb", "params" => {=>} }, hContext )
    BenchmarkAddonAssert( hResult[ "code" ] == "INVALID_MODULE", ;
        "native context does not bypass module path restrictions", @nFailures, @nChecks )

    ? "Benchmark addon checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )

RETURN

STATIC FUNCTION BenchmarkAddonRegistry( hState )

    LOCAL hRegistry := HBBridgeRegistry(), hSpec

    /* Dependency/mode arrays are required by the existing service specification. */
    hSpec := { "name" => "ADDON.Execute", "version" => 1, "params" => "H", "result" => "H", ;
        "permission" => "addon.execute", "dependencies" => {}, "modes" => { "immediate" } }
    HBBridgeRegister( hRegistry, hSpec, {| hParams, hContext | HBBridgeServiceAddon( hParams, hContext ) } )
    hSpec[ "name" ] := "RPCRDD.Query"
    hSpec[ "permission" ] := "service.call"
    HBBridgeRegister( hRegistry, hSpec, {| hParams | BenchmarkAddonQuery( hParams, hState ) } )

RETURN HBBridgeRegistrySeal( hRegistry )

STATIC FUNCTION BenchmarkAddonRun( hRegistry, hContext, hParams )
RETURN HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
    { "module" => "hbbridgebenchmarkaddon.hrb", "params" => hParams }, hContext )

STATIC FUNCTION BenchmarkAddonParams()
RETURN { "profile" => "opaque/profile", "rows" => 17, "pageSize" => 7, "iterations" => 2, "warmup" => 1 }

STATIC FUNCTION BenchmarkAddonQuery( hParams, hState )

    LOCAL hHeader := { "ID" => { "position" => 1, "type" => "N", "length" => 10, "decimals" => 0 }, ;
        "NAME" => { "position" => 2, "type" => "C", "length" => 32, "decimals" => 0 }, ;
        "AMOUNT" => { "position" => 3, "type" => "N", "length" => 15, "decimals" => 2 } }
    LOCAL hRows := {=>}, hResult

    LOCAL nPage, nSize, nCount, nRow, nID, nPages

    hState[ "calls" ]++
    IF hParams[ "alias" ] != "opaque/profile"
        RETURN HBBridgeError( "PROFILE_NOT_FOUND", "Configured fixture profile is unavailable." )
    ENDIF
    IF hState[ "failAt" ] > 0 .AND. hState[ "calls" ] == hState[ "failAt" ]
        RETURN HBBridgeError( "QUERY_FAILED", "Fixture query failed." )
    ENDIF
    nPage := hParams[ "page" ][ "number" ]
    nSize := hParams[ "page" ][ "size" ]
    nPages := Int( ( hState[ "rows" ] - 1 ) / nSize ) + 1
    hState[ "paramsValid" ] := hState[ "paramsValid" ] .AND. Len( hParams ) == 3 .AND. ;
        hParams[ "sql" ] == BenchmarkAddonSQL( hState[ "rows" ] ) .AND. ;
        Len( hParams[ "page" ] ) == 3 .AND. hParams[ "page" ][ "orderBy" ] == "ID ASC" .AND. ;
        nSize == hState[ "size" ] .AND. nPage == ( ( hState[ "calls" ] - 1 ) % nPages ) + 1
    nCount := Max( 0, Min( nSize, hState[ "rows" ] - ( nPage - 1 ) * nSize ) )
    FOR nRow := 1 TO nCount
        nID := ( nPage - 1 ) * nSize + nRow
        hRows[ hb_ntos( nRow ) ] := { "ID" => nID, "NAME" => "hbbridge-" + hb_ntos( nID ), "AMOUNT" => nID / 4 }
    NEXT
    hResult := { "success" => .T., "resultVersion" => 1, "header" => hHeader, "rows" => hRows, ;
        "rowCount" => nCount, "totalRows" => hState[ "rows" ], "totalPages" => nPages, ;
        "page" => { "number" => nPage, "size" => nSize, "hasNext" => nPage < nPages, ;
            "firstRow" => iif( nCount == 0, 0, ( nPage - 1 ) * nSize + 1 ), ;
            "lastRow" => iif( nCount == 0, 0, ( nPage - 1 ) * nSize + nCount ) } }
    DO CASE
    CASE hState[ "mode" ] == "metadata"
        hHeader[ "NAME" ][ "position" ] := 1
    CASE hState[ "mode" ] == "page"
        hResult[ "totalRows" ]++
    CASE hState[ "mode" ] == "value"
        hRows[ "1" ][ "AMOUNT" ] := -1
    CASE hState[ "mode" ] == "type"
        hRows[ "1" ][ "ID" ] := "1"
    ENDCASE

RETURN hResult

STATIC FUNCTION BenchmarkAddonSQL( nRows )

    LOCAL cDigits := "(VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9))"

RETURN "SELECT ID, CAST('hbbridge-' + CAST(ID AS VARCHAR(10)) AS VARCHAR(32)) AS NAME, " + ;
    "CAST(ID * 0.25 AS DECIMAL(15,2)) AS AMOUNT FROM (SELECT 1 + A.N + 10 * B.N + " + ;
    "100 * C.N + 1000 * D.N + 10000 * E.N AS ID FROM " + cDigits + " A(N) CROSS JOIN " + ;
    cDigits + " B(N) CROSS JOIN " + cDigits + " C(N) CROSS JOIN " + cDigits + ;
    " D(N) CROSS JOIN " + cDigits + " E(N)) F WHERE ID <= " + hb_ntos( nRows )

STATIC PROCEDURE BenchmarkAddonAssert( lCondition, cLabel, nFailures, nChecks )

    nChecks++
    IF ! lCondition
        nFailures++
    ENDIF
    ? iif( lCondition, "PASS", "FAILED" ) + ": " + cLabel

RETURN
