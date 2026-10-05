#include "dbinfo.ch"

PROCEDURE m3sqltests( nFailures, nChecks )

    LOCAL cError, cDatabase := hbbridgeabsolutepath( "sql-query.sqlite3", hb_cwd() )
    LOCAL hProfiles, hRegistry, hContext := hbbridgecontext( "test" ), hResult, hConfig, hHost := NIL
    LOCAL pConnection := NIL, nConnection, nPreviousArea := Select(), nPreviousConnection
    LOCAL hThreads := {=>}, hThread, nIndex, cSql, hNative, hJSON, hBad, oError

    hProfiles := hbbridgesqlprofiles( { "sample" => { "driver" => "sqlite", "database" => "sql-query.sqlite3" }, ;
        "missing" => { "driver" => "sqlite", "database" => "sql-query-missing.sqlite3" }, ;
        "memory" => { "driver" => "sqlite", "database" => ":memory:" }, ;
        "db/Case" => { "driver" => "sqlite", "database" => ":memory:" }, ;
        "odbc_missing" => { "driver" => "mssql", "connectionString" => "DSN=__HBBridgeMissingDSN__;" } }, ;
        hb_cwd(), @cError )
    m1assert( hProfiles != NIL .AND. hProfiles[ "sample" ][ "database" ] == cDatabase .AND. ;
        hProfiles[ "memory" ][ "database" ] == ":memory:", ;
        "SQL profiles normalize file paths and preserve the memory database", @nFailures, @nChecks )
    hBad := { "missingDriver" => { "database" => "test" }, ;
        "unknownDriver" => { "driver" => "other", "database" => "test" }, ;
        "prefixedDriver" => { "driver" => "mssql_extra", "connectionString" => "DSN=fixture" }, ;
        "emptyDatabase" => { "driver" => "sqlite", "database" => "" }, ;
        "wrongType" => { "driver" => "sqlite", "database" => 1 }, ;
        "unknownField" => { "driver" => "sqlite", "database" => "x", "password" => "secret" }, ;
        "emptyConnection" => { "driver" => "mssql", "connectionString" => "" }, ;
        "nulPath" => { "driver" => "sqlite", "database" => "x" + Chr( 0 ) } }
    FOR EACH hResult IN hBad
        m1assert( hbbridgesqlprofiles( { "bad" => hResult }, hb_cwd(), @cError ) == NIL .AND. ! Empty( cError ), ;
            "SQL profile rejects " + hResult:__enumKey(), @nFailures, @nChecks )
    NEXT
    hb_MemoWrit( "sql-config.json", '{"sqlProfiles":{"sample":{"driver":"sqlite","database":"sql-query.sqlite3"}}}' )
    hConfig := hbbridgeconfig( { "-config=sql-config.json" }, @cError )
    m1assert( hConfig != NIL .AND. hConfig[ "sqlProfiles" ][ "sample" ][ "database" ] == cDatabase, ;
        "host JSON config normalizes SQL profiles relative to its file: " + cError, @nFailures, @nChecks )
    hb_MemoWrit( "sql-config-bad.json", '{"sqlProfiles":{"sample":{"driver":"sqlite","database":null}}}' )
    m1assert( hbbridgeconfig( { "-config=sql-config-bad.json" }, @cError ) == NIL, ;
        "host config rejects invalid nested SQL profiles", @nFailures, @nChecks )

    /* Native RDD connection arrays are required by the Harbour API. */
    nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
    m1assert( nConnection > 0, "fixture creates a real SQLite database through native RDDSQL", @nFailures, @nChecks )
    IF nConnection == 0
        RETURN
    ENDIF
    m1assert( rddInfo( RDDI_EXECUTE, "CREATE TABLE samples (id INTEGER, name TEXT, amount REAL)", "SQLMIX", nConnection ), ;
        "fixture creates the SQL table", @nFailures, @nChecks )
    m1assert( rddInfo( RDDI_EXECUTE, "INSERT INTO samples VALUES (1, 'Harbour', 12.5), (2, 'hbBridge', 0.0)", "SQLMIX", nConnection ), ;
        "fixture inserts persistent rows", @nFailures, @nChecks )
    m1assert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
        "fixture connection closes", @nFailures, @nChecks )
    hRegistry := hbbridgebuiltinregistry( hProfiles )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "db/Case", "sql" => "SELECT 7 AS caller_value" }, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "CALLER_VALUE" ] == 7, ;
        "query chooses the supplied opaque slash alias without ERP resolution", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "db/case", "sql" => "SELECT 7" }, hContext )
    m1assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "PROFILE_NOT_FOUND", ;
        "query does not silently normalize profile alias case", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "memory", "sql" => "SELECT sqlite_version() AS version" }, hContext )
    m1assert( hResult[ "success" ], "SQLite runtime reports its version", @nFailures, @nChecks )
    IF hResult[ "success" ]
        ? "SQLite runtime:", AllTrim( hResult[ "rows" ][ "1" ][ "VERSION" ] )
    ENDIF
    cSql := "SELECT id, name, amount FROM samples ORDER BY id"
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", { "alias" => "sample", "sql" => cSql }, hContext )
    m1assert( hResult[ "success" ], "registered SQL service queries the persisted database", @nFailures, @nChecks )
    IF hResult[ "success" ]
        m1assert( HB_ISHASH( hResult[ "header" ] ) .AND. HB_ISHASH( hResult[ "rows" ] ) .AND. ;
            hResult[ "rowCount" ] == 2 .AND. hResult[ "resultVersion" ] == 1, ;
            "dataset contract uses keyed headers/rows and explicit row count", @nFailures, @nChecks )
        m1assert( hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
            hResult[ "header" ][ "NAME" ][ "position" ] == 2, ;
            "column names and ordinal metadata preserve the SELECT order", @nFailures, @nChecks )
        m1assert( hResult[ "rows" ][ "1" ][ "ID" ] == 1 .AND. hResult[ "rows" ][ "2" ][ "ID" ] == 2 .AND. ;
            AllTrim( hResult[ "rows" ][ "1" ][ "NAME" ] ) == "Harbour" .AND. ;
            Abs( hResult[ "rows" ][ "1" ][ "AMOUNT" ] - 12.5 ) < 0.000001, ;
            "integer/text/decimal values and ordered row keys survive the RDD", @nFailures, @nChecks )
    ENDIF
    m1assert( Select() == nPreviousArea .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "query releases its connection and restores caller area/default connection", @nFailures, @nChecks )
    m3pagetests( hRegistry, hContext, @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT id, name FROM samples WHERE id < 0" }, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0 .AND. Len( hResult[ "rows" ] ) == 0 .AND. ;
        hb_HHasKey( hResult[ "header" ], "ID" ), "empty query preserves column metadata", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "memory", "sql" => "SELECT NULL AS nullable, '' AS empty_text" }, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "NULLABLE" ] == NIL .AND. ;
        AllTrim( hResult[ "rows" ][ "1" ][ "EMPTY_TEXT" ] ) == "", ;
        "SQLite expression NULL and empty text remain distinct", @nFailures, @nChecks )
    hBad := { "INVALID_PARAMS" => { "alias" => "sample" }, ;
        "PROFILE_NOT_FOUND" => { "alias" => "unknown", "sql" => "SELECT 1" }, ;
        "CONNECTION_FAILED" => { "alias" => "missing", "sql" => "SELECT 1" }, ;
        "QUERY_FAILED" => { "alias" => "sample", "sql" => "SELECT * FROM missing_table" }, ;
        "AMBIGUOUS_COLUMN" => { "alias" => "sample", "sql" => "SELECT 1 AS value, 2 AS VALUE" } }
    FOR EACH hResult IN hBad
        hNative := hbbridgedispatch( hRegistry, "RPCRDD.Query", hResult, hContext )
        m1assert( ! hNative[ "success" ] .AND. hNative[ "code" ] == hResult:__enumKey(), ;
            "SQL service reports " + hResult:__enumKey(), @nFailures, @nChecks )
    NEXT
    m1assert( ! hb_FileExists( hProfiles[ "missing" ][ "database" ] ), ;
        "unavailable SQLite profile does not silently create a new database", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "odbc_missing", "sql" => "SELECT 1" }, hContext )
    m1assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "CONNECTION_FAILED" .AND. ;
        ! ( "DSN=" $ hb_jsonEncode( hResult ) ), "ODBC connection error does not expose its server connection string", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT 7 AS id" }, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 7 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
        "valid query works after SQL/connection failures without a stale connection", @nFailures, @nChecks )

    nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
    dbUseArea( .T., "SQLMIX", "SELECT 123 AS caller_id", hb_rddGetTempAlias(), .T., .T., NIL, nConnection )
    nIndex := Select()
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
        { "alias" => "sample", "sql" => "SELECT 7 AS id" }, hContext )
    m1assert( hResult[ "success" ] .AND. Select() == nIndex .AND. fieldget( 1 ) == 123 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
        "query preserves an existing caller SQL area and default connection", @nFailures, @nChecks )
    dbCloseArea()
    rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
    dbSelectArea( nPreviousArea )

    FOR nIndex := 1 TO 16
        hThreads[ hb_ntos( nIndex ) ] := hb_threadStart( 0, @m3parallelsql(), hRegistry, nIndex )
    NEXT
    FOR EACH hThread IN hThreads
        hResult := NIL
        hb_threadJoin( hThread, @hResult )
        m1assert( HB_ISHASH( hResult ) .AND. hResult[ "success" ] .AND. ;
            hResult[ "rows" ][ "1" ][ "ID" ] == Val( hThread:__enumKey() ), ;
            "concurrent SQL call preserves result " + hThread:__enumKey(), @nFailures, @nChecks )
    NEXT

    hConfig := hbbridgeconfig( {} )
    hConfig[ "protheusHost" ] := "127.0.0.1"
    hConfig[ "protheusPort" ] := 0
    hConfig[ "netioHost" ] := "127.0.0.1"
    hConfig[ "netioPort" ] := m1freeport()
    /* NETIO inherits a prior native client password when passed an empty one.
     * Give this fixture an explicit credential independent of earlier tests.
     */
    hConfig[ "netioPassword" ] := "sql-test-only"
    hConfig[ "netioTimeout" ] := 2000
    hConfig[ "netioRoot" ] := hbbridgeabsolutepath( "sql-netio", hb_cwd() )
    hConfig[ "sqlProfiles" ] := hProfiles
    hHost := hbbridgehoststart( hConfig, @cError )
    m1assert( hHost != NIL, "SQL profiles enable the service in the real host: " + cError, @nFailures, @nChecks )
    IF hHost != NIL
        BEGIN SEQUENCE WITH {| oError | Break( oError ) }
            pConnection := netio_GetConnection( "127.0.0.1", hConfig[ "netioPort" ], 2000, hConfig[ "netioPassword" ] )
            m1assert( ! Empty( pConnection ), "SQL native client connects to the host", @nFailures, @nChecks )
            hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", ;
                { "alias" => "sample", "sql" => cSql } )
            hJSON := mtrequest( hHost[ "listeners" ][ "protheus" ][ "port" ], ;
                hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => { "alias" => "sample", "sql" => cSql } } ) )
            m1assert( hNative[ "success" ] .AND. hJSON[ "success" ] .AND. ;
                hb_jsonEncode( hNative ) == hb_jsonEncode( hJSON ), ;
                "native NETIO and Protheus TCP return the same keyed SQL dataset", @nFailures, @nChecks )
            hBad := { "alias" => "sample", "sql" => "SELECT id, name, amount FROM samples", ;
                "page" => { "number" => 1, "size" => 1, "orderBy" => "id ASC" } }
            hNative := netio_FuncExec( pConnection, "HBBridge.Call", "RPCRDD.Query", hBad )
            hJSON := mtrequest( hHost[ "listeners" ][ "protheus" ][ "port" ], ;
                hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hBad } ) )
            m1assert( hNative[ "success" ] .AND. hJSON[ "success" ] .AND. ;
                hNative[ "rowCount" ] == 1 .AND. hNative[ "page" ][ "hasNext" ] .AND. ;
                hb_jsonEncode( hNative ) == hb_jsonEncode( hJSON ), ;
                "native NETIO and Protheus TCP share paginated SQL results", @nFailures, @nChecks )
            hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Service.List" )
            m1assert( Len( hResult[ "services" ] ) == 7 .AND. ! ( "DSN=" $ hb_jsonEncode( hResult ) ), ;
                "SQL service is discoverable without profile credentials", @nFailures, @nChecks )
        RECOVER USING oError
            cError := "Unexpected error"
            IF HB_ISOBJECT( oError )
                cError := oError:Description + "; " + oError:Operation
            ENDIF
            m1assert( .F., "SQL network integration raised an error: " + cError, @nFailures, @nChecks )
        ALWAYS
            pConnection := NIL
            netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] )
            hbbridgehoststop( hHost )
            hb_gcAll( .T. )
        END SEQUENCE
    ENDIF

RETURN

STATIC PROCEDURE m3pagetests( hRegistry, hContext, nFailures, nChecks )

    LOCAL hResult, hParams, hBad, hPage, cSql := "SELECT id, name, amount FROM samples"

    hParams := { "alias" => "sample", "sql" => cSql, ;
        "page" => { "number" => 1, "size" => 1, "orderBy" => "id ASC" } }
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ], "SQL page query uses native ROW_NUMBER", @nFailures, @nChecks )
    IF ! hResult[ "success" ]
        ? hb_jsonEncode( hResult )
        RETURN
    ENDIF
    m1assert( hResult[ "rowCount" ] == 1 .AND. Len( hResult[ "rows" ] ) == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ID" ] == 1 .AND. hResult[ "page" ][ "hasNext" ], ;
        "first page transfers only its row and detects the next one", @nFailures, @nChecks )
    m1assert( Len( hResult[ "header" ] ) == 3 .AND. hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
        ! hb_HHasKey( hResult[ "rows" ][ "1" ], "__HBBRIDGE_ROWNO" ) .AND. ;
        hResult[ "page" ][ "number" ] == 1 .AND. hResult[ "page" ][ "size" ] == 1 .AND. ;
        hResult[ "page" ][ "firstRow" ] == 1 .AND. hResult[ "page" ][ "lastRow" ] == 1, ;
        "paging metadata excludes the internal ordinal column", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 2
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ID" ] == 2 .AND. ! hResult[ "page" ][ "hasNext" ] .AND. ;
        hResult[ "page" ][ "firstRow" ] == 2, "last full page has no sentinel row", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 3
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. hResult[ "page" ][ "firstRow" ] == 0 .AND. ;
        hResult[ "page" ][ "lastRow" ] == 0 .AND. Len( hResult[ "header" ] ) == 3, ;
        "page beyond the result is empty with metadata", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 1
    hParams[ "page" ][ "size" ] := 3
    hParams[ "page" ][ "orderBy" ] := "amount DESC, id ASC"
    hParams[ "sql" ] += ";"
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 2 .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 1, ;
        "partial page supports multiple order columns and final semicolon", @nFailures, @nChecks )
    hParams[ "sql" ] := "SELECT 10 AS id, 'same' AS name UNION ALL SELECT 50, 'same' UNION ALL SELECT 90, 'same'"
    hParams[ "page" ] := { "number" => 2, "size" => 1, "orderBy" => "name, id DESC" }
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 50 .AND. ;
        hResult[ "page" ][ "hasNext" ], "page positions handle gaps and an ordering tie breaker", @nFailures, @nChecks )
    hParams[ "page" ][ "number" ] := 3
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rows" ][ "1" ][ "ID" ] == 10 .AND. ;
        ! hResult[ "page" ][ "hasNext" ], "descending pagination reaches the final noncontiguous key", @nFailures, @nChecks )
    hParams[ "sql" ] := "SELECT 1 AS [order]"
    hParams[ "page" ] := { "number" => 1, "size" => 9007199254740990, "orderBy" => "order" }
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "rows" ][ "1" ][ "ORDER" ] == 1 .AND. ! hResult[ "page" ][ "hasNext" ], ;
        "page size has no MVP cap and order aliases can be reserved words", @nFailures, @nChecks )
    hParams[ "page" ] := { "number" => 9007199254740990, "size" => 1, "orderBy" => "order" }
    hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", hParams, hContext )
    m1assert( hResult[ "success" ] .AND. hResult[ "rowCount" ] == 0, ;
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
        hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => "sample", "sql" => cSql, "page" => hPage }, hContext )
        m1assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "INVALID_PAGE", ;
            "page validation rejects " + hPage:__enumKey(), @nFailures, @nChecks )
    NEXT
    FOR EACH cSql IN { "duplicate" => "SELECT 1 AS id, 2 AS ID", ;
        "reserved" => "SELECT 1 AS __HBBRIDGE_ROWNO, 2 AS id" }
        hResult := hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
            { "alias" => "sample", "sql" => cSql, ;
            "page" => { "number" => 1, "size" => 1, "orderBy" => "id" } }, hContext )
        m1assert( ! hResult[ "success" ] .AND. hResult[ "code" ] == "AMBIGUOUS_COLUMN", ;
            "paged query rejects " + cSql:__enumKey() + " column aliases", @nFailures, @nChecks )
    NEXT

RETURN

STATIC FUNCTION m3parallelsql( hRegistry, nIndex )
RETURN hbbridgedispatch( hRegistry, "RPCRDD.Query", ;
    { "alias" => "memory", "sql" => "SELECT " + hb_ntos( nIndex ) + " AS id" }, hbbridgecontext( "test" ) )
