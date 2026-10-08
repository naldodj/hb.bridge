/* Released to Public Domain. */
#include "dbinfo.ch"

REQUEST HB_CODEPAGE_UTF8EX

/* Opt-in real MSSQL acceptance. Inputs are a private config path and an opaque
 * profile alias, never a connection string. All SQL fixtures are read-only.
 */
PROCEDURE MSSQLTests( cConfigPath, cProfile )

    LOCAL nFailures := 0, nChecks := 0, cPreviousCodepage := hb_cdpSelect()
    LOCAL nExit := 1

    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile )
        ? "MSSQL prerequisite failed: CONFIG_AND_PROFILE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    IF Empty( AllTrim( cConfigPath ) ) .OR. Empty( AllTrim( cProfile ) )
        ? "MSSQL prerequisite failed: CONFIG_AND_PROFILE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        nExit := MSSQLRun( cConfigPath, cProfile, @nFailures, @nChecks )
    RECOVER
        /* Native errors may include credentials/SQL: never render them. */
        ? "MSSQL acceptance failed: UNEXPECTED_RUNTIME_ERROR"
        nExit := 1
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE
    ErrorLevel( nExit )

RETURN

STATIC FUNCTION MSSQLRun( cConfigPath, cProfile, nFailures, nChecks )

    LOCAL hConfig, hProfiles, hRegistry, hResult, cError

    hConfig := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
    IF hConfig == NIL
        ? "MSSQL prerequisite failed: CONFIG_INVALID"
        RETURN 2
    ENDIF
    hProfiles := hConfig[ "sqlProfiles" ]
    IF ! hb_HHasKey( hProfiles, cProfile )
        ? "MSSQL prerequisite failed: PROFILE_NOT_FOUND"
        RETURN 2
    ENDIF
    IF hProfiles[ cProfile ][ "driver" ] != "mssql"
        ? "MSSQL prerequisite failed: MSSQL_PROFILE_REQUIRED"
        RETURN 2
    ENDIF
    /* Keep every other configured alias outside this test registry. */
    hRegistry := HBBridgeBuiltinRegistry( { cProfile => hProfiles[ cProfile ] } )
    hb_cdpSelect( "UTF8EX" )
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 1 AS ID" )
    IF ! MSSQLSuccess( hResult )
        ? "MSSQL prerequisite failed: " + MSSQLCode( hResult )
        RETURN 2
    ENDIF
    MSSQLAssert( MSSQLCell( hResult, 1, "ID" ) == 1, "constant connection probe", @nFailures, @nChecks )
    MSSQLAssert( hResult[ "driver" ] == "mssql", "configured native ODBC backend", @nFailures, @nChecks )
    hResult := MSSQLQuery( hRegistry, cProfile, ;
        "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar(128)) AS PRODUCT_VERSION, " + ;
        "CAST(DB_NAME() AS varchar(128)) AS DATABASE_NAME" )
    IF ! MSSQLSuccess( hResult )
        MSSQLAssert( .F., "SQL Server identification: " + MSSQLCode( hResult ), @nFailures, @nChecks )
        RETURN 1
    ENDIF
    MSSQLAssert( HB_ISSTRING( MSSQLCell( hResult, 1, "PRODUCT_VERSION" ) ) .AND. ;
        ! Empty( MSSQLCell( hResult, 1, "PRODUCT_VERSION" ) ), ;
        "SQL Server reports its version", @nFailures, @nChecks )
    MSSQLAssert( HB_ISSTRING( MSSQLCell( hResult, 1, "DATABASE_NAME" ) ) .AND. ;
        ! Empty( MSSQLCell( hResult, 1, "DATABASE_NAME" ) ), ;
        "SQL Server reports the actual database", @nFailures, @nChecks )
    IF nFailures == 0
        ? "MSSQL backend: driver=mssql; productVersion=" + AllTrim( MSSQLCell( hResult, 1, "PRODUCT_VERSION" ) ) + ;
            "; database=" + AllTrim( MSSQLCell( hResult, 1, "DATABASE_NAME" ) ) + "; codepage=UTF8EX"
    ENDIF
    MSSQLDataset( hRegistry, cProfile, @nFailures, @nChecks )
    MSSQLTypes( hRegistry, cProfile, @nFailures, @nChecks )
    MSSQLPages( hRegistry, cProfile, @nFailures, @nChecks )
    MSSQLRestoration( hRegistry, cProfile, hProfiles[ cProfile ], @nFailures, @nChecks )
    MSSQLConcurrency( hRegistry, cProfile, @nFailures, @nChecks )
    MSSQLBaseline( hRegistry, cProfile, @nFailures, @nChecks )
    ? "MSSQL checks:", nChecks, "failures:", nFailures, "skips: 0"

RETURN iif( nFailures == 0, 0, 1 )

STATIC PROCEDURE MSSQLDataset( hRegistry, cProfile, nFailures, nChecks )

    LOCAL hResult, cSQL := "SELECT 1 AS ID, 'Harbour' AS NAME, 12.5 AS AMOUNT " + ;
        "UNION ALL SELECT 2, 'hbBridge', 0.0 ORDER BY ID"

    hResult := MSSQLQuery( hRegistry, cProfile, cSQL )
    MSSQLAssert( MSSQLSuccess( hResult ), "named dataset opens: " + MSSQLCode( hResult ), @nFailures, @nChecks )
    IF MSSQLSuccess( hResult )
        MSSQLAssert( hResult[ "rowCount" ] == 2 .AND. Len( hResult[ "rows" ] ) == 2 .AND. ;
            hResult[ "resultVersion" ] == 1, "keyed dataset count and contract version", @nFailures, @nChecks )
        MSSQLAssert( hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
            hResult[ "header" ][ "NAME" ][ "position" ] == 2 .AND. ;
            hResult[ "header" ][ "AMOUNT" ][ "position" ] == 3, ;
            "named header preserves column order", @nFailures, @nChecks )
        MSSQLAssert( MSSQLCell( hResult, 1, "ID" ) == 1 .AND. MSSQLCell( hResult, 2, "ID" ) == 2, ;
            "ordered integer values", @nFailures, @nChecks )
        MSSQLAssert( AllTrim( MSSQLCell( hResult, 1, "NAME" ) ) == "Harbour" .AND. ;
            AllTrim( MSSQLCell( hResult, 2, "NAME" ) ) == "hbBridge", ;
            "ASCII values", @nFailures, @nChecks )
        MSSQLAssert( HB_ISNUMERIC( MSSQLCell( hResult, 1, "AMOUNT" ) ) .AND. ;
            Abs( MSSQLCell( hResult, 1, "AMOUNT" ) - 12.5 ) < 0.000001, ;
            "constant decimal value", @nFailures, @nChecks )
    ENDIF
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 1 AS ID, 'empty' AS NAME WHERE 1 = 0" )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        Len( hResult[ "rows" ] ) == 0 .AND. hb_HHasKey( hResult[ "header" ], "ID" ), ;
        "empty result preserves named metadata", @nFailures, @nChecks )
    /* Syntax failure cannot read any ERP table. */
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT FROM" )
    MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. MSSQLCode( hResult ) == "QUERY_FAILED", ;
        "invalid SQL has stable error code", @nFailures, @nChecks )
    MSSQLAssert( hResult[ "error" ] == "Could not open or read the SQL query result.", ;
        "invalid SQL error is sanitized", @nFailures, @nChecks )
    hResult := MSSQLQuery( hRegistry, "__HBBridgeMissingMSSQLProfile__", "SELECT 1 AS ID" )
    MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. MSSQLCode( hResult ) == "PROFILE_NOT_FOUND", ;
        "unknown alias has stable error code", @nFailures, @nChecks )
    MSSQLAssert( hResult[ "error" ] == "Connection profile is not configured.", ;
        "unknown alias error is sanitized", @nFailures, @nChecks )
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 7 AS ID" )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. MSSQLCell( hResult, 1, "ID" ) == 7, ;
        "successful query after failures", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE MSSQLTypes( hRegistry, cProfile, nFailures, nChecks )

    LOCAL hResult, hExpected, hField, cName, xActual, lValue
    LOCAL cSQL := "SELECT CAST(7 AS int) AS ID, CAST(12.50 AS decimal(10,2)) AS AMOUNT, " + ;
        "CAST(NULL AS int) AS NULL_INT, CAST(NULL AS varchar(16)) AS NULL_TEXT, " + ;
        "CAST('' AS varchar(16)) AS EMPTY_TEXT, CAST('20261007' AS date) AS EVENT_DATE, " + ;
        "CAST('2026-10-07T12:34:56.123' AS datetime2(3)) AS EVENT_TIME, CAST(1 AS bit) AS FLAG, " + ;
        "NCHAR(231) + NCHAR(227) + NCHAR(28450) + NCHAR(23383) AS UNICODE_TEXT"

    /* Expectations are native values. Decimal uses the connector's floating
     * representation with a stated tolerance; no value/type coercion is made.
     * Unicode is exact UTF-8 bytes for cedilla, a-tilde and two CJK characters.
     */
    hExpected := { "ID" => { "type" => "N", "value" => 7 }, ;
        "AMOUNT" => { "type" => "N", "value" => 12.5 }, ;
        "NULL_INT" => { "type" => "U", "value" => NIL }, ;
        "NULL_TEXT" => { "type" => "U", "value" => NIL }, ;
        "EMPTY_TEXT" => { "type" => "C", "value" => "" }, ;
        "EVENT_DATE" => { "type" => "D", "value" => hb_SToD( "20261007" ) }, ;
        "EVENT_TIME" => { "type" => "T", "value" => hb_SToT( "20261007123456.123" ) }, ;
        "FLAG" => { "type" => "L", "value" => .T. }, ;
        "UNICODE_TEXT" => { "type" => "C", "value" => hb_HexToStr( "C3A7C3A3E6BCA2E5AD97" ) } }
    hResult := MSSQLQuery( hRegistry, cProfile, cSQL )
    MSSQLAssert( MSSQLSuccess( hResult ), "typed fixture opens: " + MSSQLCode( hResult ), @nFailures, @nChecks )
    IF ! MSSQLSuccess( hResult )
        RETURN
    ENDIF
    MSSQLAssert( hResult[ "rowCount" ] == 1 .AND. Len( hResult[ "header" ] ) == Len( hExpected ), ;
        "typed fixture shape", @nFailures, @nChecks )
    FOR EACH hField IN hExpected
        cName := hField:__enumKey()
        xActual := MSSQLCell( hResult, 1, cName )
        MSSQLAssert( MSSQLHasCell( hResult, 1, cName ) .AND. ValType( xActual ) == hField[ "type" ], ;
            "native type " + cName + " expected " + hField[ "type" ] + " actual " + ValType( xActual ), ;
            @nFailures, @nChecks )
        lValue := .F.
        IF ValType( xActual ) == hField[ "type" ]
            IF cName == "AMOUNT"
                lValue := Abs( xActual - hField[ "value" ] ) < 0.000001
            ELSE
                lValue := xActual == hField[ "value" ]
            ENDIF
        ENDIF
        MSSQLAssert( MSSQLHasCell( hResult, 1, cName ) .AND. lValue, ;
            "native value " + cName, @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE MSSQLPages( hRegistry, cProfile, nFailures, nChecks )

    LOCAL cSQL := "SELECT 10 AS ID, 'same' AS NAME UNION ALL SELECT 50, 'same' UNION ALL SELECT 90, 'same'"
    LOCAL hPage := { "number" => 1, "size" => 1, "orderBy" => "NAME, ID DESC" }
    LOCAL hResult, hExpected := { "1" => 90, "2" => 50, "3" => 10 }, nID

    FOR EACH nID IN hExpected
        hPage[ "number" ] := Val( nID:__enumKey() )
        hResult := MSSQLQuery( hRegistry, cProfile, cSQL, hPage )
        MSSQLAssert( MSSQLSuccess( hResult ), "page " + nID:__enumKey() + " opens: " + MSSQLCode( hResult ), ;
            @nFailures, @nChecks )
        IF MSSQLSuccess( hResult )
            MSSQLAssert( hResult[ "rowCount" ] == 1 .AND. MSSQLCell( hResult, 1, "ID" ) == nID, ;
                "page " + nID:__enumKey() + " handles gaps and tie breaker", @nFailures, @nChecks )
            MSSQLAssert( hResult[ "page" ][ "number" ] == hPage[ "number" ] .AND. ;
                hResult[ "page" ][ "size" ] == 1 .AND. ;
                hResult[ "page" ][ "firstRow" ] == hPage[ "number" ] .AND. ;
                hResult[ "page" ][ "lastRow" ] == hPage[ "number" ] .AND. ;
                hResult[ "page" ][ "hasNext" ] == ( hPage[ "number" ] < 3 ), ;
                "page " + nID:__enumKey() + " sentinel and ordinals", @nFailures, @nChecks )
            MSSQLAssert( Len( hResult[ "header" ] ) == 2 .AND. ;
                ! hb_HHasKey( hResult[ "header" ], "__HBBRIDGE_ROWNO" ) .AND. ;
                ! MSSQLHasCell( hResult, 1, "__HBBRIDGE_ROWNO" ), ;
                "page " + nID:__enumKey() + " hides internal ordinal", @nFailures, @nChecks )
        ENDIF
    NEXT
    hPage[ "number" ] := 4
    hResult := MSSQLQuery( hRegistry, cProfile, cSQL, hPage )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hResult[ "page" ][ "firstRow" ] == 0 .AND. hResult[ "page" ][ "lastRow" ] == 0 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. Len( hResult[ "header" ] ) == 2, ;
        "page beyond result retains metadata", @nFailures, @nChecks )
    hPage[ "number" ] := 1
    hPage[ "size" ] := 4
    hResult := MSSQLQuery( hRegistry, cProfile, cSQL + ";", hPage )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. hResult[ "rowCount" ] == 3 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. MSSQLCell( hResult, 3, "ID" ) == 10, ;
        "partial page and trailing semicolon", @nFailures, @nChecks )
    hPage[ "number" ] := 0
    hResult := MSSQLQuery( hRegistry, cProfile, cSQL, hPage )
    MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. MSSQLCode( hResult ) == "INVALID_PAGE", ;
        "zero page is rejected", @nFailures, @nChecks )
    hPage[ "number" ] := 1
    hPage[ "orderBy" ] := "ID; SELECT 1"
    hResult := MSSQLQuery( hRegistry, cProfile, cSQL, hPage )
    MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. MSSQLCode( hResult ) == "INVALID_PAGE", ;
        "invalid order is rejected", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE MSSQLRestoration( hRegistry, cProfile, hProfile, nFailures, nChecks )

    LOCAL nPreviousArea := Select(), nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL nConnection := 0, nCallerArea := 0, hResult

    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 17 AS ID" )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. Select() == nPreviousArea .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "successful query restores caller area and default connection", @nFailures, @nChecks )
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT FROM" )
    MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. Select() == nPreviousArea .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "failed query restores caller area and default connection", @nFailures, @nChecks )
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        /* Native RDDSQL requires a positional connection array. No threads run
         * while this caller-owned connection is opened, queried and released.
         */
        nConnection := rddInfo( RDDI_CONNECT, { "ODBC", hProfile[ "connectionString" ] }, "SQLMIX" )
        IF nConnection == 0
            Break( NIL )
        ENDIF
        dbSelectArea( 0 )
        nCallerArea := Select()
        IF ! dbUseArea( .F., "SQLMIX", "SELECT 123 AS CALLER_ID", hb_rddGetTempAlias(), .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 19 AS ID" )
        MSSQLAssert( MSSQLSuccess( hResult ) .AND. MSSQLCell( hResult, 1, "ID" ) == 19 .AND. ;
            Select() == nCallerArea .AND. FieldGet( 1 ) == 123 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "success preserves existing SQL workarea and connection", @nFailures, @nChecks )
        hResult := MSSQLQuery( hRegistry, cProfile, "SELECT FROM" )
        MSSQLAssert( ! MSSQLSuccess( hResult ) .AND. Select() == nCallerArea .AND. FieldGet( 1 ) == 123 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "failure preserves existing SQL workarea and connection", @nFailures, @nChecks )
    RECOVER
        MSSQLAssert( .F., "caller SQL fixture: NATIVE_CONNECTION_FAILED", @nFailures, @nChecks )
    ALWAYS
        IF nCallerArea > 0
            dbSelectArea( nCallerArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        IF nConnection > 0
            MSSQLAssert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
                "caller SQL fixture connection released", @nFailures, @nChecks )
        ENDIF
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN

STATIC PROCEDURE MSSQLConcurrency( hRegistry, cProfile, nFailures, nChecks )

    LOCAL hThreads := {=>}, hThread, nIndex, hResult

    MSSQLAssert( hb_mtvm(), "native multithread runtime available", @nFailures, @nChecks )
    IF ! hb_mtvm()
        RETURN
    ENDIF
    FOR nIndex := 1 TO 4
        hThreads[ hb_ntos( nIndex ) ] := hb_threadStart( 0, @MSSQLWorker(), hRegistry, cProfile, nIndex )
    NEXT
    FOR EACH hThread IN hThreads
        hResult := NIL
        MSSQLAssert( hb_threadJoin( hThread, @hResult ), ;
            "concurrent worker " + hThread:__enumKey() + " joins", @nFailures, @nChecks )
        MSSQLAssert( MSSQLSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
            MSSQLCell( hResult, 1, "ID" ) == Val( hThread:__enumKey() ), ;
            "concurrent worker " + hThread:__enumKey() + " receives only its value", @nFailures, @nChecks )
    NEXT
    hResult := MSSQLQuery( hRegistry, cProfile, "SELECT 99 AS ID" )
    MSSQLAssert( MSSQLSuccess( hResult ) .AND. MSSQLCell( hResult, 1, "ID" ) == 99, ;
        "valid query after concurrent release", @nFailures, @nChecks )

RETURN

STATIC FUNCTION MSSQLWorker( hRegistry, cProfile, nIndex )
RETURN MSSQLQuery( hRegistry, cProfile, "SELECT " + hb_ntos( nIndex ) + " AS ID" )

STATIC PROCEDURE MSSQLBaseline( hRegistry, cProfile, nFailures, nChecks )

    LOCAL cDigits := "(VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9))"
    LOCAL cSQL := "SELECT A.N * 100 + B.N * 10 + C.N + 1 AS ID, " + ;
        "CAST('hbBridge' AS varchar(8)) AS NAME FROM " + cDigits + " AS A(N) CROSS JOIN " + ;
        cDigits + " AS B(N) CROSS JOIN " + cDigits + " AS C(N) ORDER BY ID"
    LOCAL hResult, nRun, nStarted, nElapsed, nTotal := 0

    /* Reproducible 1000-row fixture, 3 executions, concurrency 1. Includes
     * connect/open/materialize/close/disconnect; no performance threshold.
     */
    FOR nRun := 1 TO 3
        nStarted := HBBridgeMonotonicMs()
        hResult := MSSQLQuery( hRegistry, cProfile, cSQL )
        nElapsed := HBBridgeMonotonicMs() - nStarted
        nTotal += nElapsed
        MSSQLAssert( MSSQLSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1000 .AND. ;
            MSSQLCell( hResult, 1, "ID" ) == 1 .AND. MSSQLCell( hResult, 1000, "ID" ) == 1000 .AND. ;
            MSSQLCell( hResult, 1000, "NAME" ) == "hbBridge", ;
            "baseline fixture run " + hb_ntos( nRun ), @nFailures, @nChecks )
        ? "MSSQL baseline: rows=1000; concurrency=1; run=" + hb_ntos( nRun ) + "; elapsedMs=" + hb_ntos( nElapsed )
    NEXT
    ? "MSSQL baseline: executions=3; totalElapsedMs=" + hb_ntos( nTotal ) + "; memory=not-measured"

RETURN

STATIC FUNCTION MSSQLQuery( hRegistry, cProfile, cSQL, hPage )

    LOCAL hParams := { "alias" => cProfile, "sql" => cSQL }

    IF hPage != NIL
        hParams[ "page" ] := hPage
    ENDIF

RETURN HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, HBBridgeContext( "mssql-acceptance" ) )

STATIC FUNCTION MSSQLSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "success" ) .AND. hResult[ "success" ] == .T.

STATIC FUNCTION MSSQLHasCell( hResult, nRow, cName )

    LOCAL cRow := hb_ntos( nRow )

RETURN MSSQLSuccess( hResult ) .AND. hb_HHasKey( hResult, "rows" ) .AND. ;
    hb_HHasKey( hResult[ "rows" ], cRow ) .AND. hb_HHasKey( hResult[ "rows" ][ cRow ], cName )

STATIC FUNCTION MSSQLCell( hResult, nRow, cName )

    IF MSSQLHasCell( hResult, nRow, cName )
        RETURN hResult[ "rows" ][ hb_ntos( nRow ) ][ cName ]
    ENDIF

RETURN NIL

STATIC FUNCTION MSSQLCode( hResult )

    LOCAL cCode := "INVALID_RESULT"

    IF MSSQLSuccess( hResult )
        RETURN "OK"
    ENDIF
    IF HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "code" ) .AND. HB_ISSTRING( hResult[ "code" ] )
        /* Only product-defined fixed codes are allowed into diagnostic logs. */
        IF AScan( { "INVALID_PARAMS", "PROFILE_NOT_FOUND", "CONNECTION_FAILED", "QUERY_FAILED", ;
            "INVALID_PAGE", "AMBIGUOUS_COLUMN", "CONNECTION_CLOSE_FAILED", "SERVICE_ERROR", ;
            "SERVICE_NOT_FOUND", "INVALID_RESULT" }, hResult[ "code" ] ) > 0
            cCode := hResult[ "code" ]
        ENDIF
    ENDIF

RETURN cCode

STATIC PROCEDURE MSSQLAssert( lPassed, cLabel, nFailures, nChecks )

    nChecks++
    IF ! lPassed
        nFailures++
    ENDIF
    ? iif( lPassed, "PASS: ", "FAIL: " ) + cLabel

RETURN
