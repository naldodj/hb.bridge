/* Released to Public Domain. */
#include "dbinfo.ch"
#include "hbsocket.ch"

REQUEST HB_CODEPAGE_UTF8EX

/* M08 is a read-only fixture, not a load limit or a performance assertion.
 * Each invocation owns one route/process and uses the shared executor.
 * Arrays appear only in the native socket-address/config argument contracts.
 */
PROCEDURE MSSQLBenchmarkTests( cConfigPath, cProfile, cRoute, cRows, cPageSize, ;
    cIterations, cWarmup, cPooling, cTimeoutMs, cServeSeconds )

    LOCAL cPreviousCodepage

    LOCAL hReport

    LOCAL nExit

    nExit := 1
    cPreviousCodepage := hb_cdpSelect()
    hReport := { "schemaVersion" => 1, "success" => .F., "error" => "UNEXPECTED_RUNTIME_ERROR" }

    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        nExit := MBRun( cConfigPath, cProfile, cRoute, cRows, cPageSize, cIterations, ;
            cWarmup, cPooling, cTimeoutMs, cServeSeconds, hReport )
    RECOVER
        ? "MSSQL benchmark failed: UNEXPECTED_RUNTIME_ERROR"
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
        IF ! hb_MemoWrit( "result.json", hb_jsonEncode( hReport, .T. ) )
            ? "MSSQL benchmark failed: RESULT_WRITE_FAILED"
            nExit := 1
        ENDIF
    END SEQUENCE
    ? "MSSQL benchmark result:", iif( hReport[ "success" ], "OK", "FAILED" )
    ErrorLevel( nExit )

RETURN

STATIC FUNCTION MBRun( cConfigPath, cProfile, cRoute, cRows, cPageSize, ;
    cIterations, cWarmup, cPooling, cTimeoutMs, cServeSeconds, hReport )

    LOCAL cError, cSQL

    LOCAL hPrivate, hProfiles, hRegistry, hConfig, hHost, hSettings, hIteration, hSamples, hResult
    LOCAL hWarmupSamples, hChecks

    LOCAL lReady

    LOCAL nRows, nPageSize, nIterations, nWarmup, nTimeoutMs, nServeSeconds, nIndex, nStarted, nElapsed, nCalls
    LOCAL nPreviousArea, nPreviousConnection

    hHost := NIL
    nRows := MBInteger( cRows, 1, 100000 )
    nPageSize := MBInteger( cPageSize, 1, 100000 )
    nIterations := MBInteger( cIterations, 1, 1000000 )
    nWarmup := MBInteger( cWarmup, 0, 1000000 )
    nTimeoutMs := MBInteger( cTimeoutMs, 1, 2147483647 )
    nServeSeconds := iif( cServeSeconds == NIL, 0, MBInteger( cServeSeconds, 0, 3600 ) )
    hSamples := {=>}
    hWarmupSamples := {=>}
    hChecks := { "checks" => 0, "failures" => 0 }
    lReady := .F.
    nCalls := 0
    nPreviousArea := Select()
    nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )

    hReport[ "error" ] := "INVALID_ARGUMENTS"
    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile ) .OR. ;
        Empty( AllTrim( cProfile ) ) .OR. ! HB_ISSTRING( cRoute ) .OR. ;
        !( cRoute == "local" .OR. cRoute == "tcp" .OR. cRoute == "http" ) .OR. ;
        nRows == NIL .OR. nPageSize == NIL .OR. nIterations == NIL .OR. nWarmup == NIL .OR. ;
        nTimeoutMs == NIL .OR. nServeSeconds == NIL .OR. ;
        ( nServeSeconds > 0 .AND. cRoute != "http" ) .OR. ! HB_ISSTRING( cPooling ) .OR. ;
        !( cPooling == "off" .OR. cPooling == "driver" )
        ? "MSSQL benchmark prerequisite: INVALID_ARGUMENTS"
        RETURN 2
    ENDIF
    MBPhase( "setup" )
    hPrivate := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
    hReport[ "error" ] := "MSSQL_PROFILE_REQUIRED"
    IF hPrivate == NIL .OR. ! hb_HHasKey( hPrivate[ "sqlProfiles" ], cProfile ) .OR. ;
        hPrivate[ "sqlProfiles" ][ cProfile ][ "driver" ] != "mssql"
        ? "MSSQL benchmark prerequisite: MSSQL_PROFILE_REQUIRED"
        RETURN 2
    ENDIF
    hReport[ "error" ] := "ODBC_POOLING_UNAVAILABLE"
    IF ! HBBridgeSQLConfigure( cPooling, @cError )
        ? "MSSQL benchmark prerequisite: ODBC_POOLING_UNAVAILABLE"
        RETURN 2
    ENDIF
    hProfiles := { cProfile => hb_HClone( hPrivate[ "sqlProfiles" ][ cProfile ] ) }
    hRegistry := HBBridgeBuiltinRegistry( hProfiles )
    cSQL := MBFixtureSQL( nRows )
    hSettings := { "route" => cRoute, "registry" => hRegistry, "profile" => cProfile, ;
        "sql" => cSQL, "rows" => nRows, "pageSize" => nPageSize, "timeoutMs" => nTimeoutMs }
    hReport[ "fixture" ] := { "id" => "m08.constant.v1", "sql" => cSQL, "rows" => nRows, ;
        "pageSize" => nPageSize, "orderBy" => "ID", "readOnly" => .T., ;
        "columns" => { "ID" => "integer", "NAME" => "hbbridge-<ID>", "AMOUNT" => "DECIMAL(15,2): ID/4" } }
    hReport[ "settings" ] := { "route" => cRoute, "profile" => cProfile, "concurrency" => 1, ;
        "iterations" => nIterations, "warmupIterations" => nWarmup, "odbcPooling" => cPooling, ;
        "serveSeconds" => nServeSeconds, ;
        "socketTimeoutMs" => nTimeoutMs, ;
        "connectionReuse" => iif( cRoute == "local", "no client socket", "one client socket per page" ), ;
        "transportPolicy" => iif( cRoute == "local", "direct hash dispatcher", ;
            iif( cRoute == "tcp", "HBBRIDGE/1 JSON with gzip", "HTTP/1.1 plain JSON; connection close" ) ), ;
        "sqlLifecycle" => "shared mutex; page SELECT and COUNT; logical connection per page" }
    hReport[ "runtime" ] := { "harbour" => Version(), "platform" => OS(), "codepage" => "UTF8EX", ;
        "effectiveODBCDriverVersion" => "NOT_OBSERVED", "multithreaded" => hb_mtvm() }
    hReport[ "timing" ] := { "clock" => "HBBridgeMonotonicMs", "unit" => "ms", ;
        "scope" => "whole dataset: page requests, transport encode/decode and all value checks", ;
        "excluded" => "build, process/host startup, identity probe, warmup and cleanup", ;
        "resolution" => iif( "Windows" $ OS(), "GetTickCount64 native tick; typically 10-16 ms", ;
            "CLOCK_MONOTONIC truncated to milliseconds" ) }
    hReport[ "checks" ] := hChecks
    hReport[ "samples" ] := hSamples
    hReport[ "warmupSamples" ] := hWarmupSamples
    BEGIN SEQUENCE WITH __BreakBlock()
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => cProfile, "sql" => ;
                "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(128)) AS PRODUCT_VERSION, " + ;
                "CAST(DB_NAME() AS VARCHAR(128)) AS DATABASE_NAME" }, HBBridgeContext( "m08" ) )
        hReport[ "error" ] := "BACKEND_IDENTITY_FAILED"
        IF ! MBSuccess( hResult ) .OR. hResult[ "rowCount" ] != 1 .OR. ;
            ! HB_ISSTRING( MBCell( hResult, 1, "PRODUCT_VERSION" ) ) .OR. ;
            ! HB_ISSTRING( MBCell( hResult, 1, "DATABASE_NAME" ) )
            Break( NIL )
        ENDIF
        hReport[ "backend" ] := { "driver" => "mssql", ;
            "productVersion" => AllTrim( MBCell( hResult, 1, "PRODUCT_VERSION" ) ), ;
            "database" => AllTrim( MBCell( hResult, 1, "DATABASE_NAME" ) ), "identityCalls" => 1 }
        IF cRoute != "local"
            hConfig := HBBridgeConfig( {} )
            hConfig[ "protheusHost" ] := "127.0.0.1"
            hConfig[ "protheusPort" ] := 0
            hConfig[ "protheusTimeoutMs" ] := nTimeoutMs
            hConfig[ "netioHost" ] := "127.0.0.1"
            hConfig[ "netioPort" ] := MBFreePort()
            hConfig[ "netioPassword" ] := "m08-netio-test-only"
            hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "m08-netio", hb_cwd() )
            hConfig[ "sqlODBCPooling" ] := cPooling
            hConfig[ "sqlProfiles" ] := hProfiles
            hConfig[ "httpEnabled" ] := cRoute == "http"
            hConfig[ "httpHost" ] := "127.0.0.1"
            hConfig[ "httpPort" ] := MBFreePort()
            hConfig[ "httpPassword" ] := "m08-http-test-only"
            hHost := HBBridgeHostStart( hConfig, @cError )
            hReport[ "error" ] := "ISOLATED_HOST_FAILED"
            IF hHost == NIL
                Break( NIL )
            ENDIF
            hSettings[ "tcpPort" ] := hHost[ "listeners" ][ "protheus" ][ "port" ]
            hSettings[ "httpPort" ] := hConfig[ "httpPort" ]
        ENDIF
        MBPhase( "warmup" )
        hReport[ "error" ] := "WARMUP_VALIDATION_FAILED"
        FOR nIndex := 1 TO nWarmup
            nStarted := HBBridgeMonotonicMs()
            hIteration := MBIteration( hSettings, hChecks )
            hIteration[ "elapsedMs" ] := HBBridgeMonotonicMs() - nStarted
            hWarmupSamples[ hb_ntos( nIndex ) ] := hIteration
            MBCheck( hIteration[ "elapsedMs" ] >= 0, hChecks )
            IF ! hIteration[ "success" ]
                Break( NIL )
            ENDIF
            nCalls += hIteration[ "calls" ]
        NEXT
        hReport[ "warmup" ] := { "iterations" => nWarmup, "calls" => nCalls, "excludedFromSamples" => .T. }
        MBPhase( "measured" )
        hReport[ "error" ] := "MEASURED_VALIDATION_FAILED"
        FOR nIndex := 1 TO nIterations
            nStarted := HBBridgeMonotonicMs()
            hIteration := MBIteration( hSettings, hChecks )
            nElapsed := HBBridgeMonotonicMs() - nStarted
            hIteration[ "elapsedMs" ] := nElapsed
            MBCheck( nElapsed >= 0, hChecks )
            hSamples[ hb_ntos( nIndex ) ] := hIteration
            IF ! hIteration[ "success" ]
                Break( NIL )
            ENDIF
        NEXT
        hReport[ "metrics" ] := MBMetrics( hSamples )
        lReady := .T.
        IF nServeSeconds > 0 .AND. hChecks[ "failures" ] == 0
            MBPhase( "serving" )
            IF ! hb_MemoWrit( "endpoints.json", hb_jsonEncode( ;
                { "host" => "127.0.0.1", "tcpPort" => hSettings[ "tcpPort" ], ;
                "httpPort" => hSettings[ "httpPort" ], "profile" => cProfile, ;
                "token" => "m08-http-test-only", "odbcPooling" => cPooling, ;
                "backend" => hReport[ "backend" ] } ) )
                MBCheck( .F., hChecks )
                Break( NIL )
            ENDIF
            ? "M08 isolated host ready; endpoints.json contains fixture-only endpoints and token."
            nStarted := HBBridgeMonotonicMs()
            DO WHILE HBBridgeMonotonicMs() - nStarted < nServeSeconds * 1000 .AND. ;
                ! hb_FileExists( "m08.stop" )
                hb_idleSleep( 0.05 )
            ENDDO
        ENDIF
    RECOVER
        ? "MSSQL benchmark failed:", hReport[ "error" ]
    ALWAYS
        MBPhase( "cleanup" )
        IF hHost != NIL
            MBCheck( HBBridgeHostStop( hHost ), hChecks )
        ENDIF
        MBCheck( HBBridgeGetPool():Status()[ "activeLeases" ] == 0, hChecks )
        MBCheck( rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, hChecks )
        MBCheck( Select() == nPreviousArea, hChecks )
    END SEQUENCE
    hReport[ "success" ] := lReady .AND. hChecks[ "failures" ] == 0
    IF hReport[ "success" ]
        hReport[ "error" ] := ""
    ENDIF
    MBPhase( "complete" )

RETURN iif( hReport[ "success" ], 0, 1 )

STATIC FUNCTION MBFixtureSQL( nRows )

    LOCAL cDigits := "(VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9))"

RETURN "SELECT ID, CAST('hbbridge-' + CAST(ID AS VARCHAR(10)) AS VARCHAR(32)) AS NAME, " + ;
    "CAST(ID * 0.25 AS DECIMAL(15,2)) AS AMOUNT FROM " + ;
    "(SELECT 1 + A.N + 10 * B.N + 100 * C.N + 1000 * D.N + 10000 * E.N AS ID FROM " + ;
    cDigits + " A(N) CROSS JOIN " + cDigits + " B(N) CROSS JOIN " + cDigits + " C(N) CROSS JOIN " + ;
    cDigits + " D(N) CROSS JOIN " + cDigits + " E(N)) F WHERE ID <= " + hb_ntos( nRows )

STATIC FUNCTION MBIteration( hSettings, hChecks )

    LOCAL hResult, hRow, hStats

    LOCAL nPages, nPage, nRow, nExpected, nExpectedRows, nVisited

    nPages := Int( ( hSettings[ "rows" ] - 1 ) / hSettings[ "pageSize" ] ) + 1
    nVisited := 0
    hStats := { "success" => .F., "calls" => 0, "pages" => 0, "rows" => 0, "idSum" => 0 }

    FOR nPage := 1 TO nPages
        hResult := MBCall( hSettings, { "alias" => hSettings[ "profile" ], "sql" => hSettings[ "sql" ], ;
            "page" => { "number" => nPage, "size" => hSettings[ "pageSize" ], "orderBy" => "ID" } } )
        hStats[ "calls" ]++
        IF ! MBCheck( MBSuccess( hResult ), hChecks )
            RETURN hStats
        ENDIF
        nExpectedRows := Min( hSettings[ "pageSize" ], hSettings[ "rows" ] - nVisited )
        IF ! MBCheck( hResult[ "rowCount" ] == nExpectedRows .AND. Len( hResult[ "rows" ] ) == nExpectedRows .AND. ;
            hResult[ "totalRows" ] == hSettings[ "rows" ] .AND. hResult[ "totalPages" ] == nPages .AND. ;
            hResult[ "page" ][ "number" ] == nPage .AND. hResult[ "page" ][ "size" ] == hSettings[ "pageSize" ] .AND. ;
            hResult[ "page" ][ "hasNext" ] == ( nPage < nPages ) .AND. ;
            hResult[ "page" ][ "firstRow" ] == nVisited + 1 .AND. ;
            hResult[ "page" ][ "lastRow" ] == nVisited + nExpectedRows, hChecks )
            RETURN hStats
        ENDIF
        IF ! MBCheck( Len( hResult[ "header" ] ) == 3 .AND. ;
            hb_HHasKey( hResult[ "header" ], "ID" ) .AND. hb_HHasKey( hResult[ "header" ], "NAME" ) .AND. ;
            hb_HHasKey( hResult[ "header" ], "AMOUNT" ) .AND. ;
            hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
            hResult[ "header" ][ "NAME" ][ "position" ] == 2 .AND. ;
            hResult[ "header" ][ "AMOUNT" ][ "position" ] == 3, hChecks )
            RETURN hStats
        ENDIF
        FOR nRow := 1 TO nExpectedRows
            nExpected := nVisited + nRow
            hRow := hb_HGetDef( hResult[ "rows" ], hb_ntos( nRow ), NIL )
            IF ! MBCheck( HB_ISHASH( hRow ) .AND. Len( hRow ) == 3 .AND. ;
                hb_HGetDef( hRow, "ID", NIL ) == nExpected .AND. ;
                hb_HGetDef( hRow, "NAME", NIL ) == "hbbridge-" + hb_ntos( nExpected ) .AND. ;
                hb_HGetDef( hRow, "AMOUNT", NIL ) == nExpected / 4, hChecks )
                RETURN hStats
            ENDIF
            hStats[ "idSum" ] += nExpected
        NEXT
        nVisited += nExpectedRows
        hStats[ "pages" ]++
    NEXT
    hStats[ "rows" ] := nVisited
    hStats[ "success" ] := MBCheck( nVisited == hSettings[ "rows" ] .AND. ;
        hStats[ "idSum" ] == hSettings[ "rows" ] * ( hSettings[ "rows" ] + 1 ) / 2, hChecks )

RETURN hStats

STATIC FUNCTION MBCall( hSettings, hParams )

    LOCAL cReply, cBody, cRequest, cResponse, cBuffer, cHeaders, cCRLF

    LOCAL hSocket, hResult, hPolicy

    LOCAL nSent, nCount, nSeparator, nLengthAt, nLength, nTimeout, nRequestBytes

    hSocket := NIL
    hResult := NIL
    cResponse := ""
    cBuffer := Space( 65536 )
    nSent := 0
    nLength := -1
    cCRLF := Chr( 13 ) + Chr( 10 )
    nTimeout := hSettings[ "timeoutMs" ]
    hPolicy := { "protheusTimeoutMs" => nTimeout }

    IF hSettings[ "route" ] == "local"
        RETURN HBBridgeDispatch( hSettings[ "registry" ], "RPCRDD.Query", hParams, HBBridgeContext( "m08" ) )
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        hSocket := hb_socketOpen()
        IF hSettings[ "route" ] == "tcp"
            IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", hSettings[ "tcpPort" ] }, nTimeout ) .AND. ;
                SendResponse( hSocket, hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } ), hPolicy ) .AND. ;
                ReceiveRequest( hSocket, @cReply, hPolicy )
                hb_jsonDecode( cReply, @hResult )
            ENDIF
        ELSEIF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", hSettings[ "httpPort" ] }, nTimeout )
            cBody := hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } )
            cRequest := "POST /api/v1/rpc HTTP/1.1" + cCRLF + "Host: localhost" + cCRLF + ;
                "Connection: close" + cCRLF + "Content-Type: application/json" + cCRLF + ;
                "Content-Length: " + hb_ntos( hb_BLen( cBody ) ) + cCRLF + ;
                "Authorization: Bearer m08-http-test-only" + cCRLF + cCRLF + cBody
            nRequestBytes := hb_BLen( cRequest )
            DO WHILE nSent < nRequestBytes
                nCount := hb_socketSend( hSocket, hb_BSubStr( cRequest, nSent + 1 ),,, nTimeout )
                IF nCount <= 0
                    Break( NIL )
                ENDIF
                nSent += nCount
            ENDDO
            DO WHILE .T.
                nCount := hb_socketRecv( hSocket, @cBuffer,,, nTimeout )
                IF nCount <= 0
                    EXIT
                ENDIF
                cResponse += hb_BLeft( cBuffer, nCount )
            ENDDO
            nSeparator := hb_BAt( cCRLF + cCRLF, cResponse )
            IF nSeparator > 0 .AND. hb_BSubStr( cResponse, 10, 3 ) == "200"
                cHeaders := hb_BLeft( cResponse, nSeparator - 1 )
                cBody := hb_BSubStr( cResponse, nSeparator + 4 )
                nLengthAt := hb_BAt( "content-length: ", Lower( cHeaders ) )
                IF nLengthAt > 0
                    nLength := Val( hb_BSubStr( cHeaders, nLengthAt + 16 ) )
                ENDIF
                IF nLength == hb_BLen( cBody )
                    hb_jsonDecode( cBody, @hResult )
                ENDIF
            ENDIF
        ENDIF
    ALWAYS
        IF hSocket != NIL
            hb_socketClose( hSocket )
        ENDIF
    END SEQUENCE

RETURN hResult

STATIC FUNCTION MBMetrics( hSamples )

    LOCAL hSample
    LOCAL hMetrics := { "iterations" => Len( hSamples ), "totalMs" => 0, "minMs" => NIL, ;
        "maxMs" => 0, "meanMs" => 0, "calls" => 0, "rows" => 0, "pages" => 0 }

    FOR EACH hSample IN hSamples
        hMetrics[ "totalMs" ] += hSample[ "elapsedMs" ]
        hMetrics[ "calls" ] += hSample[ "calls" ]
        hMetrics[ "rows" ] += hSample[ "rows" ]
        hMetrics[ "pages" ] += hSample[ "pages" ]
        IF hMetrics[ "minMs" ] == NIL .OR. hSample[ "elapsedMs" ] < hMetrics[ "minMs" ]
            hMetrics[ "minMs" ] := hSample[ "elapsedMs" ]
        ENDIF
        hMetrics[ "maxMs" ] := Max( hMetrics[ "maxMs" ], hSample[ "elapsedMs" ] )
    NEXT
    IF Len( hSamples ) > 0
        hMetrics[ "meanMs" ] := hMetrics[ "totalMs" ] / Len( hSamples )
    ENDIF

RETURN hMetrics

STATIC FUNCTION MBInteger( cValue, nMin, nMax )

    LOCAL nValue, nChar, nLength

    IF ! HB_ISSTRING( cValue ) .OR. Empty( cValue )
        RETURN NIL
    ENDIF
    nLength := Len( cValue )
    FOR nChar := 1 TO nLength
        IF !( SubStr( cValue, nChar, 1 ) $ "0123456789" )
            RETURN NIL
        ENDIF
    NEXT
    nValue := Val( cValue )
    IF nValue < nMin .OR. nValue > nMax .OR. hb_ntos( nValue ) != cValue
        RETURN NIL
    ENDIF

RETURN nValue

STATIC FUNCTION MBSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .F. ) == .T. .AND. ;
    hb_HGetDef( hResult, "driver", "" ) == "mssql" .AND. ;
    HB_ISHASH( hb_HGetDef( hResult, "header", NIL ) ) .AND. HB_ISHASH( hb_HGetDef( hResult, "rows", NIL ) )

STATIC FUNCTION MBCell( hResult, nRow, cField )
    LOCAL hRow := hb_HGetDef( hb_HGetDef( hResult, "rows", {=>} ), hb_ntos( nRow ), NIL )
RETURN iif( HB_ISHASH( hRow ), hb_HGetDef( hRow, cField, NIL ), NIL )

STATIC FUNCTION MBFreePort()
    LOCAL hSocket := hb_socketOpen()

    LOCAL nPort := 0
    IF ! Empty( hSocket )
        IF hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
            nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
        ENDIF
        hb_socketClose( hSocket )
    ENDIF
RETURN nPort

STATIC FUNCTION MBCheck( lPassed, hChecks )
    hChecks[ "checks" ]++
    IF ! lPassed
        hChecks[ "failures" ]++
    ENDIF
RETURN lPassed

STATIC PROCEDURE MBPhase( cPhase )
    hb_MemoWrit( "phase.json", hb_jsonEncode( { "phase" => cPhase } ) )
RETURN
