/* Released to Public Domain. */
#include "dbinfo.ch"
#include "hbsocket.ch"

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE TypedQueryTests( cConfig, cProfile, cMode, cServeSeconds )

    LOCAL cCodePage := hb_cdpSelect( "UTF8EX" )
    LOCAL cDatabase := HBBridgeAbsolutePath( "typed-query.sqlite3", hb_cwd() )
    LOCAL cOutput := HBBridgeAbsolutePath( "result.json", hb_cwd() )
    LOCAL cError, cCommand

    LOCAL hReport := { "schemaVersion" => 1, "suite" => "typed.sql.integration.v1", ;
        "scope" => "Real managed SDD hook, common service, TCP and gzip HTTP; no AppServer acceptance", ;
        "checks" => { => }, "checkCount" => 0, "failureCount" => 0, ;
        "sqlite" => { "status" => "requested" }, "mssql" => { "status" => "not-requested" } }
    LOCAL hPrivate, hProfiles
    LOCAL hCommands := { "print" => "PRINT 'probe'", "return" => "RETURN", "checkpoint" => "CHECKPOINT", ;
        "reconfigure" => "RECONFIGURE", "shutdown" => "SHUTDOWN", "if" => "IF 1=1 PRINT 'probe'", ;
        "throw" => "THROW 50000, 'probe', 1", "cursor" => "OPEN cursor_name" }

    LOCAL nConnection := 0
    LOCAL nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )

    BEGIN SEQUENCE WITH {| oFailure | Break( oFailure ) }
        /* Test the lexical guard only; no administrative/batch SQL is prepared. */
        FOR EACH cCommand IN hCommands
            TQAssert( hReport, ! HBBridgeTypedSQLValid( "SELECT 1 " + cCommand ), ;
                "guard.batch." + cCommand:__enumKey() )
        NEXT
        hProfiles := HBBridgeSQLProfiles( { "typed/sqlite" => { "driver" => "sqlite", ;
            "database" => cDatabase } }, hb_cwd(), @cError )
        TQAssert( hReport, hProfiles != NIL, "sqlite.profile" )
        /* The positional array is required by native RDDI_CONNECT. */
        nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
        TQAssert( hReport, nConnection > 0, "sqlite.connect" )
        IF nConnection > 0 .AND. hProfiles != NIL
            TQSQLiteFixture( nConnection, hReport )
            TQHook( nConnection, "SELECT ID, LABEL FROM typed_fixture WHERE ID = ?", ;
                { "1" => TQBinding( "integer", 1 ) }, hReport, "sqlite.hook." )
            TQSQLite( hProfiles, nConnection, hReport )
            TQTransports( hProfiles, TQRequest( "typed/sqlite", ;
                "SELECT ID, LABEL, AMOUNT, OPTIONAL, EXACT_VALUE FROM typed_fixture WHERE ID >= ?", ;
                { "1" => TQBinding( "integer", 1 ) }, ;
                { "number" => 1, "size" => 3, "orderBy" => "ID ASC" } ), hReport, "sqlite.wire." )
            hReport[ "sqlite" ][ "status" ] := "executed"
        ENDIF
        IF ! Empty( cConfig ) .AND. ! Empty( cProfile )
            hReport[ "mssql" ][ "status" ] := "requested"
            hPrivate := HBBridgeConfig( { "-config=" + cConfig }, @cError )
            TQAssert( hReport, hPrivate != NIL, "mssql.privateConfiguration" )
            IF hPrivate != NIL
                TQMSSQL( hPrivate, cProfile, hReport )
            ENDIF
        ENDIF
    RECOVER
        /* Driver/runtime descriptions may disclose SQL or credentials. */
        TQAssert( hReport, .F., "unexpectedRuntimeError" )
    ALWAYS
        IF nConnection > 0
            TQAssert( hReport, rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), "sqlite.disconnect" )
        ENDIF
        rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        TQAssert( hReport, rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, "caller.connectionRestored" )
        TQAssert( hReport, HBBridgeGetPool():Status()[ "activeLeases" ] == 0, "caller.noActiveLeases" )
        hb_cdpSelect( cCodePage )
    END SEQUENCE
    hReport[ "success" ] := hReport[ "failureCount" ] == 0
    IF ! hb_MemoWrit( cOutput, HBBridgeJSONEncode( hReport ) + hb_eol() )
        OutStd( "FAIL writeReport" + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    OutStd( "Typed SQL integration checks=" + hb_ntos( hReport[ "checkCount" ] ) + ;
        "; failures=" + hb_ntos( hReport[ "failureCount" ] ) + hb_eol() )
    IF hReport[ "success" ] .AND. cMode == "serve"
        ErrorLevel( iif( TQServe( hProfiles, hPrivate, cProfile, cServeSeconds ), 0, 1 ) )
    ELSE
        ErrorLevel( iif( hReport[ "success" ], 0, 1 ) )
    ENDIF

RETURN

/* Keep the same reviewed backend registry alive for a separate AppServer
 * consumer. Readiness is published only after both listeners have started.
 * The ephemeral HTTP credential comes from this child process's environment;
 * private database configuration is never copied into endpoint metadata.
 */
STATIC FUNCTION TQServe( hProfiles, hPrivate, cProfile, cServeSeconds )

    LOCAL cCodePage := hb_cdpSelect( "UTF8EX" )
    LOCAL cStop := HBBridgeAbsolutePath( "stop.request", hb_cwd() )
    LOCAL cPending := HBBridgeAbsolutePath( "endpoints.pending.json", hb_cwd() )
    LOCAL cEndpoints := HBBridgeAbsolutePath( "endpoints.json", hb_cwd() )
    LOCAL cOutput := HBBridgeAbsolutePath( "serve.result.json", hb_cwd() )
    LOCAL cError, cToken := hb_GetEnv( "HBBRIDGE_TYPED_HTTP_TOKEN" )

    LOCAL hConfig := HBBridgeConfig( {} )
    LOCAL hServeProfiles := hb_HClone( hProfiles )
    LOCAL hRegistry, hEndpoints
    LOCAL hTCP := NIL, hHTTP := NIL
    LOCAL hReport := { "schemaVersion" => 1, "ready" => .F., ;
        "tcpStopped" => .F., "httpStopped" => .F., "noActiveLeases" => .F. }

    LOCAL lSuccess := .F.

    LOCAL nSeconds := Val( hb_defaultValue( cServeSeconds, "120" ) )
    LOCAL nStarted, nBudget

    hb_SetEnv( "HBBRIDGE_TYPED_HTTP_TOKEN", "" )
    BEGIN SEQUENCE WITH __BreakBlock()
        IF nSeconds < 1 .OR. nSeconds > 1800 .OR. nSeconds != Int( nSeconds ) .OR. ;
            ! TQServeTokenValid( cToken )
            OutStd( "Typed SQL serving prerequisite failed: INVALID_SERVE_SETTINGS" + hb_eol() )
            Break( NIL )
        ENDIF
        IF HB_ISHASH( hPrivate )
            hServeProfiles[ cProfile ] := hPrivate[ "sqlProfiles" ][ cProfile ]
        ELSE
            cProfile := "typed/sqlite"
        ENDIF
        hRegistry := HBBridgeBuiltinRegistry( hServeProfiles )
        hConfig[ "httpHost" ] := "127.0.0.1"
        hConfig[ "httpPort" ] := TQFreePort()
        hConfig[ "httpPassword" ] := cToken
        hConfig[ "httpCompressionMinBytes" ] := 0
        hConfig[ "maxWorkers" ] := 8
        hTCP := HBBridgeServerStart( 0, 8, "127.0.0.1", hRegistry )
        hHTTP := HBBridgeHTTPStart( hConfig, hRegistry, { => }, @cError )
        IF hTCP == NIL .OR. hHTTP == NIL
            OutStd( "Typed SQL serving prerequisite failed: LISTENER_START_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        hEndpoints := { "schemaVersion" => 1, "profile" => cProfile, ;
            "backend" => hServeProfiles[ cProfile ][ "driver" ], ;
            "tcpPort" => hTCP[ "port" ], "httpPort" => hConfig[ "httpPort" ], ;
            "httpToken" => cToken, "host" => "127.0.0.1", ;
            "serveSeconds" => nSeconds, "httpCompressionMinBytes" => 0 }
        IF ! hb_MemoWrit( cPending, HBBridgeJSONEncode( hEndpoints ) + hb_eol() ) .OR. ;
            FRename( cPending, cEndpoints ) != 0
            OutStd( "Typed SQL serving prerequisite failed: ENDPOINT_PUBLICATION_FAILED" + hb_eol() )
            Break( NIL )
        ENDIF
        hReport[ "ready" ] := .T.
        OutStd( "Typed SQL listeners ready; endpoint file=endpoints.json; stop file=stop.request" + hb_eol() )
        nStarted := HBBridgeMonotonicMs()
        nBudget := nSeconds * 1000
        DO WHILE ! hb_FileExists( cStop ) .AND. HBBridgeMonotonicMs() - nStarted < nBudget
            hb_idleSleep( 0.1 )
        ENDDO
        lSuccess := .T.
    RECOVER
        OutStd( "Typed SQL serving failed: CONTROLLED_RUNTIME_FAILURE" + hb_eol() )
    ALWAYS
        IF hHTTP != NIL
            hReport[ "httpStopped" ] := HBBridgeHTTPStop( hHTTP )
        ENDIF
        IF hTCP != NIL
            hReport[ "tcpStopped" ] := HBBridgeServerStop( hTCP )
        ENDIF
        hReport[ "noActiveLeases" ] := HBBridgeGetPool():Status()[ "activeLeases" ] == 0
        hb_cdpSelect( cCodePage )
    END SEQUENCE
    hReport[ "success" ] := lSuccess .AND. hReport[ "ready" ] .AND. ;
        hReport[ "tcpStopped" ] .AND. hReport[ "httpStopped" ] .AND. hReport[ "noActiveLeases" ]
    IF ! hb_MemoWrit( cOutput, HBBridgeJSONEncode( hReport ) + hb_eol() )
        RETURN .F.
    ENDIF

RETURN hReport[ "success" ]

STATIC FUNCTION TQServeTokenValid( cToken )

    LOCAL cHex := "0123456789ABCDEF"

    LOCAL nPosition, nSize := Len( cToken )

    IF nSize != 64
        RETURN .F.
    ENDIF
    FOR nPosition := 1 TO nSize
        IF ! ( SubStr( cToken, nPosition, 1 ) $ cHex )
            RETURN .F.
        ENDIF
    NEXT

RETURN .T.

STATIC PROCEDURE TQSQLiteFixture( nConnection, hReport )

    LOCAL cUnicode := "caf" + hb_utf8Chr( 233 ) + " " + hb_utf8Chr( 128640 )

    TQAssert( hReport, rddInfo( RDDI_EXECUTE, ;
        "CREATE TABLE typed_fixture (ID INTEGER, LABEL TEXT, AMOUNT REAL, OPTIONAL TEXT, EXACT_VALUE BIGINT)", ;
        "SQLMIX", nConnection ), "sqlite.fixtureCreate" )
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, ;
        "INSERT INTO typed_fixture VALUES (1,'alpha',1.25,NULL,9223372036854775807)," + ;
        "(2,'',2.5,'',-9223372036854775808),(3,'" + cUnicode + ;
        "'||char(0)||'tail',NULL,'tail',9007199254740993)", "SQLMIX", nConnection ), "sqlite.fixtureInsert" )
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, "CREATE TABLE typed_unsupported (VALUE DECIMAL(15,4))", ;
        "SQLMIX", nConnection ) .AND. rddInfo( RDDI_EXECUTE, "INSERT INTO typed_unsupported VALUES (NULL)", ;
        "SQLMIX", nConnection ), "sqlite.unsupportedFixture" )
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, "CREATE TABLE typed_mixed (VALUE INTEGER)", "SQLMIX", nConnection ) .AND. ;
        rddInfo( RDDI_EXECUTE, "INSERT INTO typed_mixed VALUES (7),('text')", "SQLMIX", nConnection ), "sqlite.mixedFixture" )
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, "CREATE TABLE typed_invalid_utf8 (VALUE TEXT)", "SQLMIX", nConnection ) .AND. ;
        rddInfo( RDDI_EXECUTE, "INSERT INTO typed_invalid_utf8 VALUES (CAST(X'80' AS TEXT))", ;
            "SQLMIX", nConnection ), "sqlite.invalidUTF8Fixture" )

RETURN

STATIC PROCEDURE TQHook( nConnection, cSQL, hBindings, hReport, cPrefix )

    LOCAL cSnapshot := hb_Serialize( hBindings )

    LOCAL hNative := { "operation" => "hbbridge.querytyped.v1", "sql" => cSQL, ;
        "bindings" => hBindings, "skipColumns" => 0, "rowLimit" => 0, "output" => NIL }
    LOCAL hUnknown, hOutput

    LOCAL lExecuted

    lExecuted := rddInfo( RDDI_EXECUTE, hNative, "SQLMIX", nConnection )
    TQAssert( hReport, HB_ISLOGICAL( lExecuted ) .AND. lExecuted, cPrefix + "booleanReturn" )
    hOutput := hb_HGetDef( hNative, "output", NIL )
    TQAssert( hReport, TQSuccess( hOutput ), cPrefix + "sharedHashOutputSurvives" )
    TQAssert( hReport, hNative[ "sql" ] == cSQL .AND. ;
        hNative[ "operation" ] == "hbbridge.querytyped.v1" .AND. ;
        hb_Serialize( hBindings ) == cSnapshot, cPrefix + "inputSnapshotUnchanged" )
    hUnknown := { "operation" => "hbbridge.unknown.v1", "sql" => cSQL, ;
        "bindings" => hBindings, "skipColumns" => 0, "rowLimit" => 0, "output" => NIL }
    TQAssert( hReport, ! rddInfo( RDDI_EXECUTE, hUnknown, "SQLMIX", nConnection ), cPrefix + "unknownHashRejects" )
    TQAssert( hReport, TQCode( hb_HGetDef( hUnknown, "output", NIL ) ) == "INVALID_TYPED_REQUEST", ;
        cPrefix + "unknownHashSafeFailure" )
    hNative[ "output" ] := NIL
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, hNative, "SQLMIX", nConnection ) .AND. ;
        TQSuccess( hNative[ "output" ] ), cPrefix + "successAfterUnknownHash" )
    hNative[ "sql" ] := cSQL
    hNative[ "output" ] := NIL
    /* Missing/extra markers fail before metadata; no SQL literal interpolation. */
    hNative[ "bindings" ] := { => }
    TQAssert( hReport, ! rddInfo( RDDI_EXECUTE, hNative, "SQLMIX", nConnection ) .AND. ;
        TQCode( hNative[ "output" ] ) == "INVALID_BINDINGS", cPrefix + "nativeCountMismatch" )
    TQAssert( hReport, rddInfo( RDDI_EXECUTE, "SELECT 1", "SQLMIX", nConnection ), cPrefix + "plainStringCompatibility" )

RETURN

STATIC PROCEDURE TQSQLite( hProfiles, nConnection, hReport )

    LOCAL cAlias := "typed/sqlite"
    LOCAL cSQL := "SELECT ID, LABEL, AMOUNT, OPTIONAL, EXACT_VALUE FROM typed_fixture"
    LOCAL cUnicode := "caf" + hb_utf8Chr( 233 ) + " " + hb_utf8Chr( 128640 ) + Chr( 0 ) + "tail"
    LOCAL cSnapshot

    LOCAL hBindings, hParams, hResult, hHeader, hPage, hFirstHeader, hInvalid, hCase

    LOCAL nArea := Select()

    hResult := HBBridgeSQLQuery( { "alias" => cAlias, "sql" => "SELECT ID FROM typed_fixture ORDER BY ID" }, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == 1, "sqlite.oldQueryCompatibility" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " ORDER BY ID" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ), "sqlite.noParameters" )
    IF ! TQSuccess( hResult )
        TQAssert( hReport, .F., "sqlite.resultPrerequisite" )
        RETURN
    ENDIF
    TQAssert( hReport, hResult[ "resultVersion" ] == 2 .AND. hResult[ "rowCount" ] == 3 .AND. ;
        hResult[ "totalRows" ] == 3 .AND. hResult[ "totalPages" ] == 1, "sqlite.unpagedTotalsAndVersion" )
    TQAssert( hReport, TQCell( hResult, 1, "ID" ) == "1" .AND. TQCell( hResult, 3, "ID" ) == "3", "sqlite.integerAlwaysText" )
    TQAssert( hReport, TQCell( hResult, 1, "EXACT_VALUE" ) == "9223372036854775807" .AND. ;
        TQCell( hResult, 2, "EXACT_VALUE" ) == "-9223372036854775808" .AND. ;
        TQCell( hResult, 3, "EXACT_VALUE" ) == "9007199254740993", "sqlite.exactSigned64Endpoints" )
    TQAssert( hReport, TQCell( hResult, 3, "LABEL" ) == cUnicode .AND. ;
        hb_BLen( TQCell( hResult, 3, "LABEL" ) ) == hb_BLen( cUnicode ), "sqlite.unicodeAndNulExact" )
    TQAssert( hReport, TQCell( hResult, 2, "LABEL" ) == "" .AND. ;
        hb_HHasKey( hResult[ "rows" ][ "1" ], "OPTIONAL" ) .AND. ;
        hResult[ "rows" ][ "1" ][ "OPTIONAL" ] == NIL, "sqlite.nullDistinctFromEmptyAndMissing" )
    hHeader := hResult[ "header" ]
    TQAssert( hReport, hHeader[ "ID" ][ "wire" ][ "kind" ] == "int64" .AND. ;
        hHeader[ "LABEL" ][ "wire" ][ "kind" ] == "text" .AND. ;
        hHeader[ "AMOUNT" ][ "wire" ][ "kind" ] == "number", "sqlite.fixedWireMetadata" )
    TQAssert( hReport, hHeader[ "ID" ][ "source" ][ "typeCode" ] == NIL .AND. ;
        hHeader[ "ID" ][ "source" ][ "precision" ] == NIL .AND. ;
        hHeader[ "ID" ][ "source" ][ "precisionRadix" ] == NIL .AND. ;
        hHeader[ "ID" ][ "source" ][ "nullable" ] == NIL .AND. ;
        hHeader[ "ID" ][ "rdd" ][ "type" ] == NIL, "sqlite.unknownMetadataRemainsNull" )

    hBindings := { "1" => TQBinding( "text", cUnicode ) }
    hParams := TQRequest( cAlias, cSQL + " WHERE LABEL = ?", hBindings )
    cSnapshot := hb_Serialize( hParams )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
        TQCell( hResult, 1, "LABEL" ) == cUnicode, "sqlite.nulAndUnicodeBinding" )
    TQAssert( hReport, hb_Serialize( hParams ) == cSnapshot, "sqlite.requestIsImmutable" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE LABEL = ?", ;
        { "1" => TQBinding( "text", "" ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == "2", "sqlite.emptyTextBinding" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE OPTIONAL IS ?", ;
        { "1" => TQBinding( "text", NIL ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
        TQCell( hResult, 1, "OPTIONAL" ) == NIL, "sqlite.typedNullBinding" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE EXACT_VALUE = ?", ;
        { "1" => TQBinding( "int64", "-9223372036854775808" ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == "2", "sqlite.int64MinimumBinding" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE ID >= ? AND AMOUNT >= ?", ;
        { "1" => TQBinding( "integer", 1 ), "2" => TQBinding( "number", 2.25 ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
        TQCell( hResult, 1, "ID" ) == "2", "sqlite.integerAndNumberBindings" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + ;
        " WHERE ID >= ? AND ID <= ? AND '?' = '?' /* ? */ -- ?" + hb_eol(), ;
        { "1" => TQBinding( "integer", 1 ), "2" => TQBinding( "integer", 2 ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 2, "sqlite.nativeMarkerDiscoveryIgnoresQuotedAndCommentText" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE ID = ?", ;
        { "1" => TQBinding( "boolean", .T. ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == "1", "sqlite.booleanConventionBinding" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE '2026-10-24' = ?", ;
        { "1" => TQBinding( "date", "2026-10-24" ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 3, "sqlite.dateConventionBinding" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, "SELECT OPTIONAL FROM typed_fixture WHERE ID = 1" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "OPTIONAL" ) == NIL .AND. ;
        hResult[ "header" ][ "OPTIONAL" ][ "wire" ][ "kind" ] == "text", "sqlite.allNullKeepsDeclaredMetadata" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE ID < 0" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hb_Serialize( hResult[ "header" ] ) == hb_Serialize( hHeader ), "sqlite.emptyKeepsDeclaredMetadata" )

    hPage := { "number" => 1, "size" => 1, "orderBy" => "ID ASC" }
    hBindings := { "1" => TQBinding( "integer", 2 ) }
    hParams := TQRequest( cAlias, cSQL + " WHERE ID >= ?", hBindings, hPage )
    cSnapshot := hb_Serialize( hParams )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 2 .AND. ;
        hResult[ "page" ][ "hasNext" ] .AND. TQCell( hResult, 1, "ID" ) == "2", "sqlite.boundPageAndCount" )
    IF TQSuccess( hResult )
        hFirstHeader := hb_HClone( hResult[ "header" ] )
        TQAssert( hReport, Len( hFirstHeader ) == 5 .AND. ;
            hFirstHeader[ "ID" ][ "position" ] == 1, "sqlite.generatedOrdinalHidden" )
    ELSE
        hFirstHeader := { => }
    ENDIF
    TQAssert( hReport, hb_Serialize( hParams ) == cSnapshot, "sqlite.pageAndBindingsSnapshotUnchanged" )
    hParams[ "page" ][ "number" ] := 2
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == "3" .AND. ;
        ! hResult[ "page" ][ "hasNext" ] .AND. hResult[ "totalRows" ] == 2 .AND. ;
        hb_Serialize( hResult[ "header" ] ) == hb_Serialize( hFirstHeader ), "sqlite.secondPageStableMetadata" )
    hParams[ "page" ][ "number" ] := 9
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 2 .AND. ;
        hResult[ "page" ][ "firstRow" ] == 0 .AND. hResult[ "page" ][ "lastRow" ] == 0 .AND. ;
        hb_Serialize( hResult[ "header" ] ) == hb_Serialize( hFirstHeader ), "sqlite.beyondLastKeepsTotalsAndMetadata" )

    hInvalid := { ;
        "namedMarker" => { "sql" => cSQL + " WHERE ID = :id", "bindings" => { "1" => TQBinding( "integer", 1 ) }, "code" => "INVALID_BINDINGS" }, ;
        "numberedMarker" => { "sql" => cSQL + " WHERE ID = ?1", "bindings" => { "1" => TQBinding( "integer", 1 ) }, "code" => "INVALID_BINDINGS" }, ;
        "missingBinding" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { => }, "code" => "INVALID_BINDINGS" }, ;
        "extraBinding" => { "sql" => cSQL, "bindings" => { "1" => TQBinding( "integer", 1 ) }, "code" => "INVALID_BINDINGS" }, ;
        "ordinalGap" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "2" => TQBinding( "integer", 1 ) }, "code" => "INVALID_BINDINGS" }, ;
        "int64Overflow" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "1" => TQBinding( "int64", "9223372036854775808" ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "int64NegativeZero" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "1" => TQBinding( "int64", "-0" ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "integerFraction" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "1" => TQBinding( "integer", 1.5 ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "integerUnsafe" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "1" => TQBinding( "integer", 9007199254740992 ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "invalidUTF8Binding" => { "sql" => cSQL + " WHERE LABEL = ?", "bindings" => { "1" => TQBinding( "text", hb_HexToStr( "80" ) ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "invalidDate" => { "sql" => cSQL + " WHERE ID = ?", "bindings" => { "1" => TQBinding( "date", "2026-02-30" ) }, "code" => "BINDING_RANGE_ERROR" }, ;
        "unknownEmptyExpression" => { "sql" => "SELECT 1 + 1 AS VALUE WHERE 0", "bindings" => { => }, "code" => "UNSUPPORTED_RESULT_TYPE" }, ;
        "unsupportedEmptyDeclared" => { "sql" => "SELECT VALUE FROM typed_unsupported WHERE 0", "bindings" => { => }, "code" => "UNSUPPORTED_RESULT_TYPE" }, ;
        "unsupportedAllNullDeclared" => { "sql" => "SELECT VALUE FROM typed_unsupported", "bindings" => { => }, "code" => "UNSUPPORTED_RESULT_TYPE" }, ;
        "mixedStorage" => { "sql" => "SELECT VALUE FROM typed_mixed ORDER BY rowid", "bindings" => { => }, "code" => "UNSUPPORTED_RESULT_TYPE" }, ;
        "invalidUTF8Result" => { "sql" => "SELECT VALUE FROM typed_invalid_utf8", "bindings" => { => }, "code" => "RESULT_RANGE_ERROR" }, ;
        "multipleStatements" => { "sql" => cSQL + "; SELECT 1", "bindings" => { => }, "code" => "INVALID_TYPED_REQUEST" } }
    FOR EACH hCase IN hInvalid
        hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, hCase[ "sql" ], hCase[ "bindings" ] ), hProfiles )
        TQAssert( hReport, TQCode( hResult ) == hCase[ "code" ] .AND. ;
            ! hb_HHasKey( hResult, "rows" ), "sqlite.reject." + hCase:__enumKey() )
    NEXT
    hBindings := { "1" => { "type" => "decimal", "isNull" => .T., "precision" => 15, "scale" => 4 } }
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " WHERE ID = ?", hBindings ), hProfiles )
    TQAssert( hReport, TQCode( hResult ) == "UNSUPPORTED_BINDING_TYPE", "sqlite.fixedDecimalNullUnsupported" )
    hParams := TQRequest( cAlias, cSQL )
    hParams[ "unknown" ] := .T.
    TQAssert( hReport, TQCode( HBBridgeSQLQueryTyped( hParams, hProfiles ) ) == "INVALID_TYPED_REQUEST", "sqlite.unknownRequestMember" )
    hb_HDel( hParams, "unknown" )
    hParams[ "requestVersion" ] := 99
    TQAssert( hReport, TQCode( HBBridgeSQLQueryTyped( hParams, hProfiles ) ) == "UNSUPPORTED_REQUEST_VERSION", "sqlite.unsupportedVersion" )
    hParams := TQRequest( cAlias, "SELECT ID AS X, LABEL AS X FROM typed_fixture" )
    TQAssert( hReport, TQCode( HBBridgeSQLQueryTyped( hParams, hProfiles ) ) == "UNSUPPORTED_RESULT_TYPE", ;
        "sqlite.duplicateProjectionUnpaged" )
    hParams[ "page" ] := { "number" => 1, "size" => 2, "orderBy" => "X ASC" }
    TQAssert( hReport, TQCode( HBBridgeSQLQueryTyped( hParams, hProfiles ) ) == "UNSUPPORTED_RESULT_TYPE", ;
        "sqlite.duplicateProjectionPaged" )
    hParams[ "sql" ] := "SELECT ID, LABEL AS __HBBRIDGE_ROWNO_TEXT FROM typed_fixture"
    hParams[ "page" ][ "orderBy" ] := "ID ASC"
    TQAssert( hReport, TQCode( HBBridgeSQLQueryTyped( hParams, hProfiles ) ) == "UNSUPPORTED_RESULT_TYPE", ;
        "sqlite.reservedProjectionPaged" )
    hParams := TQRequest( cAlias, cSQL + " WHERE ID >= ? -- trailing comment", ;
        { "1" => TQBinding( "integer", 1 ) }, { "number" => 1, "size" => 2, "orderBy" => "ID ASC" } )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 2 .AND. ;
        hResult[ "totalRows" ] == 3, "sqlite.pagedTrailingComment" )
    hParams[ "sql" ] += Chr( 10 )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 2 .AND. ;
        hResult[ "totalRows" ] == 3, "sqlite.pagedTrailingCommentWithLF" )
    hResult := HBBridgeSQLQuery( { "alias" => cAlias, "sql" => cSQL + " -- trailing comment", ;
        "page" => hParams[ "page" ] }, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 2 .AND. ;
        hResult[ "totalRows" ] == 3, "sqlite.oldQueryTrailingComment" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cAlias, cSQL + " ORDER BY ID" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 3, "sqlite.recoveryAfterFailures" )
    TQAssert( hReport, rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection .AND. ;
        Select() == nArea, "sqlite.callerConnectionAndAreaPreserved" )
    TQAssert( hReport, HBBridgeGetPool():Status()[ "activeLeases" ] == 0, "sqlite.allServiceLeasesReleased" )

RETURN

STATIC PROCEDURE TQMSSQL( hPrivate, cProfile, hReport )

    LOCAL cError, cValue, cCase

    LOCAL hProfiles, hResult, hValues, hBindings, hParams, hLease

    LOCAL nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )

    IF ! hb_HHasKey( hPrivate[ "sqlProfiles" ], cProfile )
        TQAssert( hReport, .F., "mssql.profileExists" )
        RETURN
    ENDIF
    hProfiles := { cProfile => hPrivate[ "sqlProfiles" ][ cProfile ] }
    TQAssert( hReport, hProfiles[ cProfile ][ "driver" ] == "mssql", "mssql.profileDriver" )
    IF hProfiles[ cProfile ][ "driver" ] != "mssql"
        RETURN
    ENDIF
    TQAssert( hReport, HBBridgeSQLConfigure( hPrivate[ "sqlODBCPooling" ], @cError ), "mssql.poolingPolicy" )
    TQAssert( hReport, HBBridgeGetPool():RegisterProfile( cProfile, hProfiles[ cProfile ] ), "mssql.registerHookProfile" )
    hLease := HBBridgeGetPool():Acquire( cProfile )
    TQAssert( hReport, hLease != NIL, "mssql.acquireHookLease" )
    IF hLease != NIL
        BEGIN SEQUENCE WITH {| oFailure | Break( oFailure ) }
            TQHook( hLease[ "connection" ], "SELECT CAST(? AS bigint) AS EXACT_VALUE", ;
                { "1" => TQBinding( "int64", "-9223372036854775808" ) }, hReport, "mssql.hook." )
        ALWAYS
            TQAssert( hReport, HBBridgeGetPool():Release( hLease ), "mssql.releaseHookLease" )
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        END SEQUENCE
    ENDIF
    hValues := { "maximum" => "9223372036854775807", "minimum" => "-9223372036854775808", ;
        "aboveBinary64" => "9007199254740993" }
    FOR EACH cValue IN hValues
        cCase := cValue:__enumKey()
        hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(? AS bigint) AS EXACT_VALUE", ;
            { "1" => TQBinding( "int64", cValue ) } ), hProfiles )
        TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "EXACT_VALUE" ) == cValue, "mssql.int64." + cCase )
    NEXT
    cValue := "caf" + hb_utf8Chr( 233 ) + " " + hb_utf8Chr( 128640 ) + Chr( 0 ) + "tail"
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(? AS nvarchar(max)) AS LABEL", ;
        { "1" => TQBinding( "text", cValue ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "LABEL" ) == cValue, "mssql.unicodeAndNul" )
    hBindings := { "1" => { "type" => "decimal", "isNull" => .F., "precision" => 30, ;
        "scale" => 10, "value" => "12345678901234567890.1234567890" } }
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(? AS decimal(30,10)) AS AMOUNT", hBindings ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. ;
        TQCell( hResult, 1, "AMOUNT" ) == hBindings[ "1" ][ "value" ], "mssql.exactDecimalBindingAndResult" )
    IF TQSuccess( hResult )
        TQAssert( hReport, hResult[ "header" ][ "AMOUNT" ][ "source" ][ "precision" ] == 30 .AND. ;
            hResult[ "header" ][ "AMOUNT" ][ "source" ][ "scale" ] == 10 .AND. ;
            hResult[ "header" ][ "AMOUNT" ][ "source" ][ "precisionRadix" ] == 10, "mssql.decimalSourceMetadata" )
    ENDIF
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(0 AS decimal(12,4)) AS AMOUNT" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "AMOUNT" ) == "0.0000", "mssql.decimalZeroCanonicalization" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(? AS date) AS ON_DATE", ;
        { "1" => TQBinding( "date", "2026-10-24" ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ON_DATE" ) == "2026-10-24", "mssql.nativeDate" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(? AS bit) AS FLAG", ;
        { "1" => TQBinding( "boolean", .T. ) } ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "FLAG" ) == .T., "mssql.nativeBoolean" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, ;
        "SELECT CAST(NULL AS nvarchar(20)) AS ABSENT, CAST(N'' AS nvarchar(20)) AS EMPTY_TEXT" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ABSENT" ) == NIL .AND. ;
        TQCell( hResult, 1, "EMPTY_TEXT" ) == "", "mssql.nullDistinctFromEmpty" )
    hParams := TQRequest( cProfile, "SELECT CAST(ID AS int) AS ID FROM (VALUES(1),(2),(3)) AS fixture(ID) WHERE ID >= ?", ;
        { "1" => TQBinding( "integer", 2 ) }, { "number" => 1, "size" => 1, "orderBy" => "ID ASC" } )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "totalRows" ] == 2 .AND. ;
        hResult[ "totalPages" ] == 2 .AND. TQCell( hResult, 1, "ID" ) == 2 .AND. ;
        hResult[ "page" ][ "hasNext" ], "mssql.boundPageAndCount" )
    hParams[ "sql" ] += " -- trailing comment"
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "totalRows" ] == 2 .AND. ;
        hResult[ "rowCount" ] == 1, "mssql.pagedTrailingComment" )
    hParams[ "sql" ] += Chr( 10 )
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "totalRows" ] == 2 .AND. ;
        hResult[ "rowCount" ] == 1, "mssql.pagedTrailingCommentWithLF" )
    hParams[ "page" ][ "number" ] := 8
    hResult := HBBridgeSQLQueryTyped( hParams, hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. hResult[ "rowCount" ] == 0 .AND. ;
        hResult[ "totalRows" ] == 2 .AND. hResult[ "totalPages" ] == 2, "mssql.emptyPageKeepsTotals" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(0x0102 AS varbinary(2)) AS PAYLOAD WHERE 1=0" ), hProfiles )
    TQAssert( hReport, TQCode( hResult ) == "UNSUPPORTED_RESULT_TYPE", "mssql.emptyBinaryUnsupported" )
    hResult := HBBridgeSQLQueryTyped( TQRequest( cProfile, "SELECT CAST(1 AS int) AS ID" ), hProfiles )
    TQAssert( hReport, TQSuccess( hResult ) .AND. TQCell( hResult, 1, "ID" ) == 1, "mssql.recoveryAfterFailure" )
    TQAssert( hReport, HBBridgeGetPool():Status()[ "activeLeases" ] == 0 .AND. ;
        rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, "mssql.noLeasesAndCallerRestored" )
    hReport[ "mssql" ][ "status" ] := "executed"
    TQTransports( hProfiles, TQRequest( cProfile, ;
        "SELECT CAST(? AS bigint) AS EXACT_VALUE, CAST(? AS nvarchar(max)) AS LABEL, " + ;
        "CAST(NULL AS nvarchar(20)) AS OPTIONAL, CAST(? AS decimal(30,10)) AS AMOUNT", ;
        { "1" => TQBinding( "int64", "9007199254740993" ), "2" => TQBinding( "text", cValue ), ;
            "3" => hBindings[ "1" ] }, ;
        { "number" => 1, "size" => 1, "orderBy" => "EXACT_VALUE ASC" } ), hReport, "mssql.wire." )

RETURN

/* Exercise the actual registry and byte transports against the same native
 * backend, including generated page/count binding and exact JSON values.
 */
STATIC PROCEDURE TQTransports( hProfiles, hParams, hReport, cPrefix )

    LOCAL cError, cRoute, cPath, cRequest, cResult, cExpected

    LOCAL hRegistry := HBBridgeBuiltinRegistry( hProfiles )
    LOCAL hConfig := HBBridgeConfig( {} )
    LOCAL hTCP := NIL, hHTTP := NIL, hSocket := NIL
    LOCAL hResult, hNative, hResponse, hInvalid
    LOCAL hRoutes := { "tcp" => "/api/v1/rpc", "http" => "/api/v1/rpc", ;
        "rest" => "/api/v1/services/RPCRDD.QueryTyped" }

    hConfig[ "httpHost" ] := "127.0.0.1"
    hConfig[ "httpPort" ] := TQFreePort()
    hConfig[ "httpPassword" ] := "typed-wire-test-only"
    hConfig[ "httpCompressionMinBytes" ] := 0
    hNative := HBBridgeDispatch( hRegistry, "RPCRDD.QueryTyped", hParams, HBBridgeContext( "typed-test" ) )
    TQAssert( hReport, TQSuccess( hNative ), cPrefix + "nativePrerequisite" )
    IF ! TQSuccess( hNative )
        RETURN
    ENDIF
    cExpected := HBBridgeJSONEncode( hNative )
    BEGIN SEQUENCE WITH __BreakBlock()
        hTCP := HBBridgeServerStart( 0, 8, "127.0.0.1", hRegistry )
        hHTTP := HBBridgeHTTPStart( hConfig, hRegistry, { => }, @cError )
        TQAssert( hReport, hTCP != NIL .AND. hHTTP != NIL, cPrefix + "listeners" )
        IF hTCP == NIL .OR. hHTTP == NIL
            Break( NIL )
        ENDIF
        FOR EACH cPath IN hRoutes
            cRoute := cPath:__enumKey()
            cRequest := HBBridgeJSONEncode( { "service" => "RPCRDD.QueryTyped", "params" => hParams } )
            hResult := NIL
            IF cRoute == "tcp"
                hSocket := hb_socketOpen()
                /* Socket address arrays are required by the native socket API. */
                IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", hTCP[ "port" ] }, 5000 )
                    IF SendResponse( hSocket, cRequest ) .AND. ReceiveRequest( hSocket, @cResult )
                        HBBridgeJSONDecode( cResult, @hResult )
                    ENDIF
                ENDIF
                hb_socketClose( hSocket )
                hSocket := NIL
            ELSE
                hResponse := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", hRoutes[ cRoute ], ;
                    iif( cRoute == "rest", HBBridgeJSONEncode( hParams ), cRequest ), ;
                    "Bearer " + hConfig[ "httpPassword" ], NIL, "Accept-Encoding: gzip, identity;q=0" )
                TQAssert( hReport, hResponse[ "status" ] == 200 .AND. ;
                    "content-encoding: gzip" $ Lower( hResponse[ "headers" ] ), cPrefix + cRoute + ".gzip" )
                HBBridgeJSONDecode( hResponse[ "decodedBody" ], @hResult )
            ENDIF
            TQAssert( hReport, TQSuccess( hResult ) .AND. HBBridgeJSONEncode( hResult ) == cExpected, ;
                cPrefix + cRoute + ".exactResultAndMetadata" )
        NEXT
        hInvalid := hb_HClone( hParams )
        hInvalid[ "requestVersion" ] := 99
        hResponse := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", hRoutes[ "rest" ], ;
            HBBridgeJSONEncode( hInvalid ), "Bearer " + hConfig[ "httpPassword" ], NIL, ;
            "Accept-Encoding: gzip, identity;q=0" )
        HBBridgeJSONDecode( hResponse[ "decodedBody" ], @hResult )
        TQAssert( hReport, hResponse[ "status" ] >= 400 .AND. ;
            TQCode( hResult ) == "UNSUPPORTED_REQUEST_VERSION" .AND. ! hb_HHasKey( hResult, "rows" ), ;
            cPrefix + "structuredFailure" )
        hResponse := HBBridgeHTTPTestRequest( hConfig[ "httpPort" ], "POST", hRoutes[ "rest" ], ;
            HBBridgeJSONEncode( hParams ), "Bearer " + hConfig[ "httpPassword" ] )
        HBBridgeJSONDecode( hResponse[ "decodedBody" ], @hResult )
        TQAssert( hReport, TQSuccess( hResult ) .AND. HBBridgeJSONEncode( hResult ) == cExpected, ;
            cPrefix + "recoveryAfterFailure" )
    ALWAYS
        IF hSocket != NIL
            hb_socketClose( hSocket )
        ENDIF
        IF hHTTP != NIL
            TQAssert( hReport, HBBridgeHTTPStop( hHTTP ), cPrefix + "httpStopped" )
        ENDIF
        IF hTCP != NIL
            TQAssert( hReport, HBBridgeServerStop( hTCP ), cPrefix + "tcpStopped" )
        ENDIF
    END SEQUENCE

RETURN

STATIC FUNCTION TQFreePort()

    LOCAL aAddress

    LOCAL hSocket := hb_socketOpen()

    hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    aAddress := hb_socketGetSockName( hSocket )
    hb_socketClose( hSocket )

RETURN aAddress[ HB_SOCKET_ADINFO_PORT ]

STATIC FUNCTION TQRequest( cAlias, cSQL, hBindings, hPage )

    LOCAL hParams := { "requestVersion" => 1, "alias" => cAlias, "sql" => cSQL, ;
        "bindings" => iif( hBindings == NIL, { => }, hBindings ) }

    IF hPage != NIL
        hParams[ "page" ] := hPage
    ENDIF

RETURN hParams

STATIC FUNCTION TQBinding( cType, xValue )

    LOCAL hBinding := { "type" => cType, "isNull" => xValue == NIL }

    IF xValue != NIL
        hBinding[ "value" ] := xValue
    ENDIF

RETURN hBinding

STATIC FUNCTION TQSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "success" ) .AND. ;
    HB_ISLOGICAL( hResult[ "success" ] ) .AND. hResult[ "success" ]

STATIC FUNCTION TQCode( hResult )

    IF HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "code" ) .AND. ;
        HB_ISSTRING( hResult[ "code" ] ) .AND. hb_HHasKey( hResult, "error" ) .AND. ;
        HB_ISSTRING( hResult[ "error" ] )
        RETURN hResult[ "code" ]
    ENDIF
    IF HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "error" ) .AND. HB_ISHASH( hResult[ "error" ] )
        RETURN hb_HGetDef( hResult[ "error" ], "code", "" )
    ENDIF

RETURN ""

STATIC FUNCTION TQCell( hResult, nRow, cField )

    LOCAL cRow := hb_ntos( nRow )

    IF TQSuccess( hResult ) .AND. hb_HHasKey( hResult, "rows" ) .AND. ;
        hb_HHasKey( hResult[ "rows" ], cRow ) .AND. hb_HHasKey( hResult[ "rows" ][ cRow ], cField )
        RETURN hResult[ "rows" ][ cRow ][ cField ]
    ENDIF

RETURN NIL

STATIC PROCEDURE TQAssert( hReport, lSuccess, cName )

    hReport[ "checks" ][ cName ] := lSuccess
    hReport[ "checkCount" ]++
    IF ! lSuccess
        hReport[ "failureCount" ]++
    ENDIF
    OutStd( iif( lSuccess, "PASS ", "FAIL " ) + cName + hb_eol() )

RETURN
