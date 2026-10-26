#include "dbinfo.ch"

PROCEDURE M3SQLTests( nFailures, nChecks )

    LOCAL cError, cDatabase, cSql

    LOCAL hProfiles, hRegistry, hContext, hResult, hConfig, hHost, hThreads, hThread, hNative, hJSON, hBad

    LOCAL nConnection, nPreviousArea, nPreviousConnection, nIndex, nFreeArea, nAttempt

    LOCAL oError

    LOCAL pConnection

    cDatabase := HBBridgeAbsolutePath( "sql-query.sqlite3", hb_cwd() )
    hContext := HBBridgeContext( "test" )
    hHost := NIL
    pConnection := NIL
    nPreviousArea := Select()
    hThreads := {=>}

    hProfiles := HBBridgeSQLProfiles( { "sample" => { "driver" => "sqlite", "database" => "sql-query.sqlite3" }, ;
        "missing" => { "driver" => "sqlite", "database" => "sql-query-missing.sqlite3" }, ;
        "memory" => { "driver" => "sqlite", "database" => ":memory:" }, ;
        "db/Case" => { "driver" => "sqlite", "database" => ":memory:" }, ;
        "odbc_missing" => { "driver" => "mssql", ;
            "connectionString" => "DSN=__HBBridgeMissingDSN__;UID=m06-test-user;PWD=m06-test-secret;" } }, ;
        hb_cwd(), @cError )
    M1Assert( hProfiles != NIL .AND. hProfiles[ "sample" ][ "database" ] == cDatabase .AND. ;
        hProfiles[ "memory" ][ "database" ] == ":memory:", ;
        "SQL profiles normalize file paths and preserve the memory database", @nFailures, @nChecks )
    M6SQLTimeoutConfigTests( @nFailures, @nChecks )
    hBad := { "missingDriver" => { "database" => "test" }, ;
        "unknownDriver" => { "driver" => "other", "database" => "test" }, ;
        "prefixedDriver" => { "driver" => "mssql_extra", "connectionString" => "DSN=fixture" }, ;
        "emptyDatabase" => { "driver" => "sqlite", "database" => "" }, ;
        "wrongType" => { "driver" => "sqlite", "database" => 1 }, ;
        "unknownField" => { "driver" => "sqlite", "database" => "x", "password" => "secret" }, ;
        "emptyConnection" => { "driver" => "mssql", "connectionString" => "" }, ;
        "nulPath" => { "driver" => "sqlite", "database" => "x" + Chr( 0 ) } }
    FOR EACH hResult IN hBad
        M1Assert( HBBridgeSQLProfiles( { "bad" => hResult }, hb_cwd(), @cError ) == NIL .AND. ! Empty( cError ), ;
            "SQL profile rejects " + hResult:__enumKey(), @nFailures, @nChecks )
    NEXT
    hb_MemoWrit( "sql-config.json", '{"sqlProfiles":{"sample":{"driver":"sqlite","database":"sql-query.sqlite3"}}}' )
    hConfig := HBBridgeConfig( { "-config=sql-config.json" }, @cError )
    M1Assert( hConfig != NIL .AND. hConfig[ "sqlProfiles" ][ "sample" ][ "database" ] == cDatabase, ;
        "host JSON config normalizes SQL profiles relative to its file: " + cError, @nFailures, @nChecks )
    hb_MemoWrit( "sql-config-bad.json", '{"sqlProfiles":{"sample":{"driver":"sqlite","database":null}}}' )
    M1Assert( HBBridgeConfig( { "-config=sql-config-bad.json" }, @cError ) == NIL, ;
        "host config rejects invalid nested SQL profiles", @nFailures, @nChecks )

    /* Native RDD connection arrays are required by the Harbour API. */
    nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
    M1Assert( nConnection > 0, "fixture creates a real SQLite database through native RDDSQL", @nFailures, @nChecks )
    IF nConnection == 0
        RETURN
    ENDIF
    M1Assert( rddInfo( RDDI_EXECUTE, "CREATE TABLE samples (id INTEGER, name TEXT, amount REAL)", "SQLMIX", nConnection ), ;
        "fixture creates the SQL table", @nFailures, @nChecks )
    M1Assert( rddInfo( RDDI_EXECUTE, "INSERT INTO samples VALUES (1, 'Harbour', 12.5), (2, 'hbBridge', 0.0)", "SQLMIX", nConnection ), ;
        "fixture inserts persistent rows", @nFailures, @nChecks )
    M1Assert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
        "fixture connection closes", @nFailures, @nChecks )
    hRegistry := HBBridgeBuiltinRegistry( hProfiles )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "db/Case", "sql" => "SELECT 7 AS caller_value" }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "CALLER_VALUE" ] == 7, ;
        "query chooses the supplied opaque slash alias without ERP resolution", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "db/case", "sql" => "SELECT 7" }, hContext )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "PROFILE_NOT_FOUND", ;
        "query does not silently normalize profile alias case", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "memory", "sql" => "SELECT sqlite_version() AS version" }, hContext )
    M1Assert( hResult[ "success" ], "SQLite runtime reports its version", @nFailures, @nChecks )
    IF hResult[ "success" ]
        ? "SQLite runtime:", AllTrim( hResult[ "rows" ][ "1" ][ "VERSION" ] )
    ENDIF
    cSql := "SELECT id, name, amount FROM samples ORDER BY id"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", { "alias" => "sample", "sql" => cSql }, hContext )
    M1Assert( hResult[ "success" ], "registered SQL service queries the persisted database", @nFailures, @nChecks )
    IF hResult[ "success" ]
        M1Assert( HB_ISHASH( hResult[ "header" ] ) .AND. HB_ISHASH( hResult[ "rows" ] ) .AND. ;
            hResult[ "rowCount" ] == 2 .AND. hResult[ "resultVersion" ] == 1, ;
            "dataset contract uses keyed headers/rows and explicit row count", @nFailures, @nChecks )
        M1Assert( hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
            hResult[ "header" ][ "NAME" ][ "position" ] == 2, ;
            "column names and ordinal metadata preserve the SELECT order", @nFailures, @nChecks )
        M1Assert( hResult[ "rows" ][ "1" ][ "ID" ] == 1 .AND. hResult[ "rows" ][ "2" ][ "ID" ] == 2 .AND. ;
            AllTrim( hResult[ "rows" ][ "1" ][ "NAME" ] ) == "Harbour" .AND. ;
            Abs( hResult[ "rows" ][ "1" ][ "AMOUNT" ] - 12.5 ) < 0.000001, ;
            "integer/text/decimal values and ordered row keys survive the RDD", @nFailures, @nChecks )
    ENDIF
    M1Assert( Select() == nPreviousArea .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "query releases its connection and restores caller area/default connection", @nFailures, @nChecks )
    M3PageTests( hRegistry, hContext, @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT id, name FROM samples WHERE id < 0" }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0 .AND. Len( hResult[ "rows" ] ) == 0 .AND. ;
        hb_HHasKey( hResult[ "header" ], "ID" ), "empty query preserves column metadata", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "memory", "sql" => "SELECT NULL AS nullable, '' AS empty_text" }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "NULLABLE" ] == NIL .AND. ;
        AllTrim( hResult[ "rows" ][ "1" ][ "EMPTY_TEXT" ] ) == "", ;
        "SQLite expression NULL and empty text remain distinct", @nFailures, @nChecks )
    hBad := { "INVALID_PARAMS" => { "alias" => "sample" }, ;
        "PROFILE_NOT_FOUND" => { "alias" => "unknown", "sql" => "SELECT 1" }, ;
        "CONNECTION_FAILED" => { "alias" => "missing", "sql" => "SELECT 1" }, ;
        "QUERY_FAILED" => { "alias" => "sample", "sql" => "SELECT * FROM missing_table" }, ;
        "AMBIGUOUS_COLUMN" => { "alias" => "sample", "sql" => "SELECT 1 AS value, 2 AS VALUE" } }
    FOR EACH hResult IN hBad
        hNative := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hResult, hContext )
        M1Assert( ! hNative[ "success" ] .AND. hNative[ "code" ] == hResult:__enumKey(), ;
            "SQL service reports " + hResult:__enumKey(), @nFailures, @nChecks )
    NEXT
    M1Assert( ! hb_FileExists( hProfiles[ "missing" ][ "database" ] ), ;
        "unavailable SQLite profile does not silently create a new database", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "odbc_missing", "sql" => "SELECT 1" }, hContext )
    M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "CONNECTION_FAILED" .AND. ;
        ! ( "DSN=" $ hb_jsonEncode( hResult ) ), "ODBC connection error does not expose its server connection string", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT 7 AS id" }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 7 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "valid query works after SQL/connection failures without a stale connection", @nFailures, @nChecks )

    nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
    dbUseArea( .T., "SQLMIX", "SELECT 123 AS caller_id", hb_rddGetTempAlias(), .T., .T., NIL, nConnection )
    nIndex := Select()
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT 7 AS id" }, hContext )
    M1Assert( hResult[ "success" ] .AND. Select() == nIndex .AND. FieldGet( 1 ) == 123 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
        "query preserves an existing caller SQL area and default connection", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT id FROM samples", ;
            "page" => { "number" => 1, "size" => 1, "orderBy" => "id" } }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "totalRows" ] == 2 .AND. ;
        Select() == nIndex .AND. FieldGet( 1 ) == 123 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
        "page reader and count preserve the caller workarea and connection", @nFailures, @nChecks )
    dbSelectArea( 0 )
    nFreeArea := Select()
    dbSelectArea( nIndex )
    FOR nAttempt := 1 TO 3
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => "sample", "sql" => "SELECT * FROM missing_table" }, hContext )
        M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "QUERY_FAILED" .AND. ;
            Select() == nIndex .AND. FieldGet( 1 ) == 123 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "failed SQL OPEN preserves the caller area and connection", @nFailures, @nChecks )
        dbSelectArea( 0 )
        M1Assert( Select() == nFreeArea .AND. ! Used(), ;
            "failed SQL OPEN does not consume a free workarea", @nFailures, @nChecks )
        dbSelectArea( nIndex )
    NEXT
    dbCloseArea()
    rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
    dbSelectArea( nPreviousArea )

    FOR nIndex := 1 TO 16
        hThreads[ hb_ntos( nIndex ) ] := hb_threadStart( 0, @M3ParallelSQL(), hRegistry, nIndex )
    NEXT
    FOR EACH hThread IN hThreads
        hResult := NIL
        hb_threadJoin( hThread, @hResult )
        M1Assert( HB_ISHASH( hResult ) .AND. hResult[ "success" ] .AND. ;
            hResult[ "rows" ][ "1" ][ "ID" ] == Val( hThread:__enumKey() ), ;
            "concurrent SQL call preserves result " + hThread:__enumKey(), @nFailures, @nChecks )
    NEXT

    hConfig := HBBridgeConfig( {} )
    hConfig[ "protheusHost" ] := "127.0.0.1"
    hConfig[ "protheusPort" ] := 0
    hConfig[ "netioHost" ] := "127.0.0.1"
    hConfig[ "netioPort" ] := M1FreePort()
    /* NETIO inherits a prior native client password when passed an empty one.
     * Give this fixture an explicit credential independent of earlier tests.
     */
    hConfig[ "netioPassword" ] := "sql-test-only"
    hConfig[ "netioTimeout" ] := 2000
    hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "sql-netio", hb_cwd() )
    hConfig[ "sqlProfiles" ] := hProfiles
    hHost := HBBridgeHostStart( hConfig, @cError )
    M1Assert( hHost != NIL, "SQL profiles enable the service in the real host: " + cError, @nFailures, @nChecks )
    IF hHost != NIL
        BEGIN SEQUENCE WITH {| oError | Break( oError ) }
            pConnection := netio_GetConnection( "127.0.0.1", hConfig[ "netioPort" ], 2000, hConfig[ "netioPassword" ] )
            M1Assert( ! Empty( pConnection ), "SQL native client connects to the host", @nFailures, @nChecks )
            hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", ;
                { "alias" => "sample", "sql" => cSql } )
            hJSON := MTRequest( hHost[ "listeners" ][ "protheus" ][ "port" ], ;
                hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => { "alias" => "sample", "sql" => cSql } } ) )
            M1Assert( hNative[ "success" ] .AND. hJSON[ "success" ] .AND. ;
                hb_jsonEncode( hNative ) == hb_jsonEncode( hJSON ), ;
                "native NETIO and Protheus TCP return the same keyed SQL dataset", @nFailures, @nChecks )
            hBad := { "alias" => "sample", "sql" => "SELECT id, name, amount FROM samples", ;
                "page" => { "number" => 1, "size" => 1, "orderBy" => "id ASC" } }
            hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", hBad )
            hJSON := MTRequest( hHost[ "listeners" ][ "protheus" ][ "port" ], ;
                hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hBad } ) )
            M1Assert( hNative[ "success" ] .AND. hJSON[ "success" ] .AND. ;
                hNative[ "rowCount" ] == 1 .AND. hNative[ "page" ][ "hasNext" ] .AND. ;
                hb_jsonEncode( hNative ) == hb_jsonEncode( hJSON ), ;
                "native NETIO and Protheus TCP share paginated SQL results", @nFailures, @nChecks )
            M6SQLNetworkFailures( hHost, pConnection, @nFailures, @nChecks )
            hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Service.List" )
            M1Assert( Len( hResult[ "services" ] ) == 8 .AND. ;
                AScan( hResult[ "services" ], {| hService | hService[ "name" ] == "RPCRDD.Query" } ) > 0 .AND. ;
                AScan( hResult[ "services" ], {| hService | hService[ "name" ] == "RPCRDD.QueryTyped" } ) > 0 .AND. ;
                ! ( "DSN=" $ hb_jsonEncode( hResult ) ), ;
                "SQL service is discoverable without profile credentials", @nFailures, @nChecks )
        RECOVER USING oError
            cError := "Unexpected error"
            IF HB_ISOBJECT( oError )
                cError := oError:Description + "; " + oError:Operation
            ENDIF
            M1Assert( .F., "SQL network integration raised an error: " + cError, @nFailures, @nChecks )
        ALWAYS
            pConnection := NIL
            netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] )
            HBBridgeHostStop( hHost )
            hb_gcAll( .T. )
        END SEQUENCE
    ENDIF

RETURN

STATIC PROCEDURE M6SQLNetworkFailures( hHost, pConnection, nFailures, nChecks )

    LOCAL cName

    LOCAL hCases, hCase, hNative, hJSON, hRecovery

    LOCAL nPort := hHost[ "listeners" ][ "protheus" ][ "port" ]

    /* All connections belong to the isolated fixture. A missing DSN exercises
     * the real Driver Manager failure without reaching an external server.
     */
    hCases := { "invalidSQL" => { "params" => { "alias" => "sample", ;
            "sql" => "SELECT * FROM m06_private_sql_marker" }, ;
            "code" => "QUERY_FAILED", "error" => "Could not open or read the SQL query result." }, ;
        "unknownProfile" => { "params" => { "alias" => "m06_private_profile_marker", "sql" => "SELECT 1" }, ;
            "code" => "PROFILE_NOT_FOUND", "error" => "Connection profile is not configured." }, ;
        "missingDatabase" => { "params" => { "alias" => "missing", "sql" => "SELECT 1" }, ;
            "code" => "CONNECTION_FAILED", "error" => "Database connection is unavailable." }, ;
        "missingODBC" => { "params" => { "alias" => "odbc_missing", "sql" => "SELECT 1" }, ;
            "code" => "CONNECTION_FAILED", "error" => "Database connection is unavailable." } }
    hRecovery := { "alias" => "sample", "sql" => "SELECT 77 AS recovery_id" }
    FOR EACH hCase IN hCases
        cName := hCase:__enumKey()
        hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", hCase[ "params" ] )
        M1Assert( M6SQLSafeFailure( hNative, hCase ), ;
            "NETIO SQL failure has a safe envelope without partial data: " + cName, @nFailures, @nChecks )
        hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", hRecovery )
        M1Assert( M6SQLRecovered( hNative ), ;
            "NETIO SQL recovers after each failure on the same connection: " + cName, @nFailures, @nChecks )
        hJSON := MTRequest( nPort, hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hCase[ "params" ] } ) )
        M1Assert( M6SQLSafeFailure( hJSON, hCase ), ;
            "TCP SQL failure has a safe envelope without partial data: " + cName, @nFailures, @nChecks )
        hJSON := MTRequest( nPort, hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hRecovery } ) )
        M1Assert( M6SQLRecovered( hJSON ), ;
            "TCP SQL recovers after each failure: " + cName, @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE M6SQLTimeoutConfigTests( nFailures, nChecks )

    LOCAL cError, cKey, cINI

    LOCAL hProfiles, hInput, hBad, hINI
    LOCAL hTimeouts := { "loginTimeoutSeconds" => .T., "queryTimeoutSeconds" => .F. }

    LOCAL lLogin

    LOCAL xBad

    hInput := { "driver" => "mssql", "connectionString" => "DSN=timeout-test-only;" }
    hProfiles := HBBridgeSQLProfiles( { "timeout/test" => hInput }, hb_cwd(), @cError )
    M1Assert( hProfiles != NIL .AND. ! hb_HHasKey( hProfiles[ "timeout/test" ], "loginTimeoutSeconds" ) .AND. ;
        ! hb_HHasKey( hProfiles[ "timeout/test" ], "queryTimeoutSeconds" ), ;
        "omitted SQL timeouts retain native defaults", @nFailures, @nChecks )
    FOR EACH lLogin IN hTimeouts
        cKey := lLogin:__enumKey()
        hInput[ cKey ] := 0
        hProfiles := HBBridgeSQLProfiles( { "timeout/test" => hInput }, hb_cwd(), @cError )
        M1Assert( hProfiles != NIL .AND. hProfiles[ "timeout/test" ][ cKey ] == 0, ;
            "explicit zero is preserved for " + cKey, @nFailures, @nChecks )
        hInput[ cKey ] := HBBridgeODBCTimeoutMax( lLogin )
        hProfiles := HBBridgeSQLProfiles( { "timeout/test" => hInput }, hb_cwd(), @cError )
        M1Assert( hProfiles != NIL .AND. hProfiles[ "timeout/test" ][ cKey ] == hInput[ cKey ], ;
            "SQL timeout accepts its compiled native capacity: " + cKey, @nFailures, @nChecks )
        hBad := { "negative" => -1, "fractional" => 1.5, "text" => "2", "null" => NIL, ;
            "logical" => .T., "overflow" => HBBridgeODBCTimeoutMax( lLogin ) + 1 }
        FOR EACH xBad IN hBad
            hInput[ cKey ] := xBad
            M1Assert( HBBridgeSQLProfiles( { "timeout/test" => hInput }, hb_cwd(), @cError ) == NIL, ;
                "SQL timeout rejects " + xBad:__enumKey() + " for " + cKey, @nFailures, @nChecks )
        NEXT
        hInput[ cKey ] := 2
    NEXT
    hInput := { "driver" => "mssql", "dsn" => "timeout-test-only", "authentication" => "integrated", ;
        "loginTimeoutSeconds" => 2, "queryTimeoutSeconds" => 1 }
    hProfiles := HBBridgeSQLProfiles( { "timeout/test" => hInput }, hb_cwd(), @cError )
    M1Assert( hProfiles != NIL .AND. hProfiles[ "timeout/test" ][ "loginTimeoutSeconds" ] == 2 .AND. ;
        hProfiles[ "timeout/test" ][ "queryTimeoutSeconds" ] == 1 .AND. ;
        ! ( "Timeout" $ hProfiles[ "timeout/test" ][ "connectionString" ] ), ;
        "structured SQL profiles keep native timeout options outside credentials", @nFailures, @nChecks )
    M1Assert( HBBridgeSQLProfiles( { "bad" => { "driver" => "sqlite", "database" => ":memory:", ;
        "queryTimeoutSeconds" => 1 } }, hb_cwd(), @cError ) == NIL, ;
        "SQLite rejects unsupported ODBC timeout options", @nFailures, @nChecks )
    cINI := "[SQL/timeout/test]" + hb_eol() + "Driver=mssql" + hb_eol() + ;
        "ConnectionString=DSN=timeout-test-only;" + hb_eol() + "LoginTimeoutSeconds=2" + hb_eol() + ;
        "QueryTimeoutSeconds=0" + hb_eol()
    hINI := HBBridgeConfigINI( cINI, HBBridgeConfig( {} ), @cError )
    hProfiles := HBBridgeSQLProfiles( hINI[ "sqlProfiles" ], hb_cwd(), @cError )
    M1Assert( hProfiles != NIL .AND. hProfiles[ "timeout/test" ][ "loginTimeoutSeconds" ] == 2 .AND. ;
        hProfiles[ "timeout/test" ][ "queryTimeoutSeconds" ] == 0, ;
        "INI SQL timeouts are typed numbers and preserve explicit zero", @nFailures, @nChecks )
    M1Assert( HBBridgeConfigINI( StrTran( cINI, "Seconds=0", "Seconds=01" ), HBBridgeConfig( {} ), @cError ) == NIL, ;
        "INI SQL timeout rejects noncanonical numeric text", @nFailures, @nChecks )

RETURN

STATIC FUNCTION M6SQLSafeFailure( hResult, hCase )
    IF ! HB_ISHASH( hResult )
        RETURN .F.
    ENDIF
    /* Exactly the public error fields: no rows/header/totals/driver details.
     * Exact text also excludes fixture SQL, paths and synthetic credentials.
     */
RETURN Len( hResult ) == 4 .AND. hb_HGetDef( hResult, "success", .T. ) == .F. .AND. ;
    hb_HGetDef( hResult, "code", "" ) == hCase[ "code" ] .AND. ;
    hb_HGetDef( hResult, "error", "" ) == hCase[ "error" ] .AND. ;
    hb_HGetDef( hResult, "message", NIL ) == ""

STATIC FUNCTION M6SQLRecovered( hResult )
    IF ! HB_ISHASH( hResult ) .OR. hb_HGetDef( hResult, "success", .F. ) != .T.
        RETURN .F.
    ENDIF
    IF ! HB_ISHASH( hb_HGetDef( hResult, "rows", NIL ) ) .OR. ;
        ! HB_ISHASH( hb_HGetDef( hResult, "header", NIL ) )
        RETURN .F.
    ENDIF
    IF ! HB_ISHASH( hb_HGetDef( hResult[ "rows" ], "1", NIL ) )
        RETURN .F.
    ENDIF
RETURN hb_HGetDef( hResult, "rowCount", 0 ) == 1 .AND. Len( hResult[ "rows" ] ) == 1 .AND. ;
    Len( hResult[ "header" ] ) == 1 .AND. ;
    hb_HGetDef( hResult[ "rows" ][ "1" ], "RECOVERY_ID", NIL ) == 77

STATIC PROCEDURE M3PageTests( hRegistry, hContext, nFailures, nChecks )

    LOCAL cSql := "SELECT id, name, amount FROM samples"

    LOCAL hResult, hParams, hBad, hPage

    hParams := { "alias" => "sample", "sql" => cSql, ;
        "page" => { "number" => 1, "size" => 1, "orderBy" => "id ASC" } }
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ], "SQL page query uses native ROW_NUMBER", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        ? hb_jsonEncode( hResult )
        RETURN
    ENDIF
    M1Assert( hResult[ "rowCount" ] == 1 .AND. Len( hResult[ "rows" ] ) == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ID" ] == 1 .AND. hResult[ "page" ][ "hasNext" ], ;
        "first page transfers only its row and detects the next one", @nFailures, @nChecks )
    M1Assert( hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 2, ;
        "exact-multiple page totals describe the entire result", @nFailures, @nChecks )
    M1Assert( Len( hResult[ "header" ] ) == 3 .AND. hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
        ! hb_HHasKey( hResult[ "rows" ][ "1" ], "__HBBRIDGE_ROWNO" ) .AND. ;
        hResult[ "page" ][ "number" ] == 1 .AND. hResult[ "page" ][ "size" ] == 1 .AND. ;
        hResult[ "page" ][ "firstRow" ] == 1 .AND. hResult[ "page" ][ "lastRow" ] == 1, ;
        "paging metadata excludes the internal ordinal column", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 2
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ID" ] == 2 .AND. ! hResult[ "page" ][ "hasNext" ] .AND. ;
        hResult[ "page" ][ "firstRow" ] == 2, "last full page has no sentinel row", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 3
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. hResult[ "page" ][ "firstRow" ] == 0 .AND. ;
        hResult[ "page" ][ "lastRow" ] == 0 .AND. Len( hResult[ "header" ] ) == 3, ;
        "page beyond the result is empty with metadata", @nFailures, @nChecks )
    M1Assert( hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 2, ;
        "an out-of-range page retains full-query totals", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 1
    hParams[ "page" ][ "size" ] := 3
    hParams[ "page" ][ "orderBy" ] := "amount DESC, id ASC"
    hParams[ "sql" ] += ";"
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 2 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 1, ;
        "partial page supports multiple order columns and final semicolon", @nFailures, @nChecks )
    M1Assert( hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 1, ;
        "partial page totals never inflate the actual row count", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT id FROM samples WHERE id < 0", ;
            "page" => { "number" => 1, "size" => 2, "orderBy" => "id" } }, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hResult[ "totalRows" ] == 0 .AND. hResult[ "totalPages" ] == 0 .AND. ;
        ! hResult[ "page" ][ "hasNext" ], ;
        "empty paged results expose zero rows and zero total pages", @nFailures, @nChecks )
    hParams[ "sql" ] := "SELECT 10 AS id, 'same' AS name UNION ALL SELECT 50, 'same' UNION ALL SELECT 90, 'same'"
    hParams[ "page" ] := { "number" => 2, "size" => 1, "orderBy" => "name, id DESC" }
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 50 .AND. ;
        hResult[ "page" ][ "hasNext" ], "page positions handle gaps and an ordering tie breaker", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 3
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 10 .AND. ;
        ! hResult[ "page" ][ "hasNext" ], "descending pagination reaches the final noncontiguous key", @nFailures, @nChecks )
    hParams[ "sql" ] := "SELECT 1 AS [order]"
    hParams[ "page" ] := { "number" => 1, "size" => 9007199254740990, "orderBy" => "order" }
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ORDER" ] == 1 .AND. ! hResult[ "page" ][ "hasNext" ], ;
        "page size has no MVP cap and order aliases can be reserved words", @nFailures, @nChecks )
    hParams[ "page" ] := { "number" => 9007199254740990, "size" => 1, "orderBy" => "order" }
    hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    M1Assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0, ;
        "largest exact final ordinal including sentinel is accepted", @nFailures, @nChecks )
    hBad := { "notObject" => NIL, "missingField" => { "number" => 1, "size" => 1 }, ;
        "zeroPage" => { "number" => 0, "size" => 1, "orderBy" => "id" }, ;
        "negativeSize" => { "number" => 1, "size" => -1, "orderBy" => "id" }, ;
        "fraction" => { "number" => 1.5, "size" => 1, "orderBy" => "id" }, ;
        "wrongType" => { "number" => "1", "size" => 1, "orderBy" => "id" }, ;
        "overflow" => { "number" => 9007199254740990, "size" => 2, "orderBy" => "id" }, ;
        "sentinelOverflow" => { "number" => 1, "size" => 9007199254740991, "orderBy" => "id" }, ;
        "emptyOrder" => { "number" => 1, "size" => 1, "orderBy" => "" }, ;
        "expression" => { "number" => 1, "size" => 1, "orderBy" => "id; SELECT 1" }, ;
        "directionTail" => { "number" => 1, "size" => 1, "orderBy" => "id ASC NULLS LAST" }, ;
        "directionBatch" => { "number" => 1, "size" => 1, "orderBy" => "id DESC; SELECT 1" }, ;
        "trailingComma" => { "number" => 1, "size" => 1, "orderBy" => "id," }, ;
        "extraField" => { "number" => 1, "size" => 1, "orderBy" => "id", "extra" => 1 } }
    FOR EACH hPage IN hBad
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => "sample", "sql" => cSql, "page" => hPage }, hContext )
        M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_PAGE", ;
            "page validation rejects " + hPage:__enumKey(), @nFailures, @nChecks )
    NEXT
    FOR EACH cSql IN { "duplicate" => "SELECT 1 AS id, 2 AS ID", ;
        "reserved" => "SELECT 1 AS __HBBRIDGE_ROWNO, 2 AS id" }
        hResult := HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => "sample", "sql" => cSql, ;
            "page" => { "number" => 1, "size" => 1, "orderBy" => "id" } }, hContext )
        M1Assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "AMBIGUOUS_COLUMN", ;
            "paged query rejects " + cSql:__enumKey() + " column aliases", @nFailures, @nChecks )
    NEXT

RETURN

STATIC FUNCTION M3ParallelSQL( hRegistry, nIndex )
RETURN HBBridgeDispatch( hRegistry, "RPCRDD.Query", ;
    { "alias" => "memory", "sql" => "SELECT " + hb_ntos( nIndex ) + " AS id" }, HBBridgeContext( "test" ) )
