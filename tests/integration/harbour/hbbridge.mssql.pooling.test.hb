/* Released to Public Domain. */
#include "dbinfo.ch"

REQUEST HB_CODEPAGE_UTF8EX

/* Opt-in physical ODBC reuse acceptance. Run off/driver in separate processes:
 * Driver Manager pooling is selected before the first ODBC environment.
 * The primary account must be allowed to inspect its current connection in
 * sys.dm_exec_connections. SPID alone cannot prove physical connection reuse.
 * No ERP tables are read or changed; mutations affect this test's session and
 * its local temporary table only. An optional second alias must use another DB.
 */
PROCEDURE MSSQLPoolingTests( cConfigPath, cProfile, cMode, cOtherProfile )

    LOCAL cPreviousCodepage

    LOCAL nExit

    nExit := 1
    cPreviousCodepage := hb_cdpSelect()

    hb_default( @cMode, "driver" )
    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile ) .OR. ;
        ! ( cMode == "off" .OR. cMode == "driver" )
        ? "MSSQL pooling prerequisite: CONFIG_PROFILE_AND_MODE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        nExit := MPRun( cConfigPath, cProfile, cMode, cOtherProfile )
    RECOVER
        ? "MSSQL pooling acceptance: UNEXPECTED_RUNTIME_ERROR"
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE
    ErrorLevel( nExit )

RETURN

STATIC FUNCTION MPRun( cConfigPath, cProfile, cMode, cOtherProfile )

    LOCAL cError, cSwitch

    LOCAL hChecks, hConfig, hProfile, hProfiles, hBaseline, hSnapshot, hPairs, hInfo, hOther, hResult
    LOCAL hIdentityParts, hWarmup, hSlow, hFast

    LOCAL lReady

    LOCAL nIndex, nPreviousArea, nPreviousConnection, nStarted, nSwitch

    hChecks := { "checks" => 0, "failures" => 0 }
    hPairs := {=>}
    hIdentityParts := { "ports" => {=>}, "connections" => {=>}, "started" => {=>} }
    hWarmup := {=>}
    nPreviousArea := Select()
    nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    nStarted := HBBridgeMonotonicMs()
    lReady := .F.

    IF ! HBBridgeODBCPooling( cMode )
        ? "MSSQL pooling prerequisite: REQUESTED_MODE_UNAVAILABLE"
        RETURN 2
    ENDIF
    hInfo := HBBridgeODBCPoolingInfo()
    MPAssert( hInfo[ "mode" ] == cMode .AND. ! hInfo[ "frozen" ], ;
        "pool mode selected before the first ODBC environment", hChecks )
    hConfig := HBBridgeConfig( { "-config=" + cConfigPath, "-odbcpooling=" + cMode }, @cError )
    IF hConfig == NIL .OR. ! hb_HHasKey( hConfig[ "sqlProfiles" ], cProfile )
        ? "MSSQL pooling prerequisite: PROFILE_INVALID"
        RETURN 2
    ENDIF
    hProfile := hb_HClone( hConfig[ "sqlProfiles" ][ cProfile ] )
    IF hProfile[ "driver" ] != "mssql"
        ? "MSSQL pooling prerequisite: MSSQL_PROFILE_REQUIRED"
        RETURN 2
    ENDIF
    hProfile[ "loginTimeoutSeconds" ] := 2
    hProfile[ "queryTimeoutSeconds" ] := 4
    hProfiles := { cProfile => hProfile }
    hSlow := hb_HClone( hProfile )
    hSlow[ "queryTimeoutSeconds" ] := 1
    hFast := hb_HClone( hProfile )
    hFast[ "loginTimeoutSeconds" ] := 3
    hProfiles[ "m07/pooling-slow" ] := hSlow
    hProfiles[ "m07/pooling-fast" ] := hFast
    IF cProfile == "m07/pooling-slow" .OR. cProfile == "m07/pooling-fast"
        ? "MSSQL pooling prerequisite: RESERVED_TEST_ALIAS"
        RETURN 2
    ENDIF
    IF HB_ISSTRING( cOtherProfile ) .AND. ! Empty( cOtherProfile )
        IF ! hb_HHasKey( hConfig[ "sqlProfiles" ], cOtherProfile ) .OR. ;
            hConfig[ "sqlProfiles" ][ cOtherProfile ][ "driver" ] != "mssql" .OR. ;
            cOtherProfile == cProfile .OR. cOtherProfile == "m07/pooling-slow" .OR. ;
            cOtherProfile == "m07/pooling-fast"
            ? "MSSQL pooling prerequisite: OTHER_PROFILE_INVALID"
            RETURN 2
        ENDIF
        hProfiles[ cOtherProfile ] := hb_HClone( hConfig[ "sqlProfiles" ][ cOtherProfile ] )
    ENDIF
    hProfiles := HBBridgeSQLProfiles( hProfiles, hb_cwd(), @cError )
    IF hProfiles == NIL
        ? "MSSQL pooling prerequisite: TEST_PROFILE_INVALID"
        RETURN 2
    ENDIF
    hBaseline := MPSnapshot( hProfiles, cProfile )
    IF ! MPIdentityValid( hBaseline )
        ? "MSSQL pooling prerequisite: PHYSICAL_CONNECTION_IDENTITY_UNAVAILABLE"
        RETURN 2
    ENDIF
    /* The inspected DMV/cursor snapshot reports XACT_STATE=1 with no user
     * transaction even in the fresh pool-off control. Reject an uncommittable
     * baseline and compare later snapshots against the same observed state.
     */
    IF hBaseline[ "TRAN_COUNT" ] != 0 .OR. ;
        ! ( hBaseline[ "XACT_STATE" ] == 0 .OR. hBaseline[ "XACT_STATE" ] == 1 ) .OR. ;
        hBaseline[ "TEMP_PRESENT" ] != 0 .OR. hBaseline[ "CONTEXT_PRESENT" ] != 0
        ? "MSSQL pooling prerequisite: INITIAL_SESSION_NOT_CLEAN"
        ? "MSSQL initial session flags:", hb_jsonEncode( { "transactions" => hBaseline[ "TRAN_COUNT" ], ;
            "transactionState" => hBaseline[ "XACT_STATE" ], "temporaryTable" => hBaseline[ "TEMP_PRESENT" ], ;
            "testContext" => hBaseline[ "CONTEXT_PRESENT" ] } )
        RETURN 2
    ENDIF
    IF AllTrim( hBaseline[ "TRANSPORT" ] ) == "TCP"
        ? "MSSQL physical transport: TCP"
    ELSE
        ? "MSSQL physical transport: NON_TCP; SQL pooling cannot reduce TCP port churn on this database leg."
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        MPAssert( nPreviousConnection == 0, "isolated test starts without a caller connection", hChecks )
        /* Record cold-start behavior separately. The inspected driver manager
         * opened two connections during initialization, then reused one in
         * steady state. Neither the warmup nor its physical cost is hidden.
         */
        hWarmup[ MPIdentity( hBaseline ) ] := .T.
        hSnapshot := MPSnapshot( hProfiles, cProfile )
        MPAssert( MPIdentityValid( hSnapshot ) .AND. MPStateMatches( hSnapshot, hBaseline ), ;
            "second cold-start lease preserves clean session state", hChecks )
        IF ! MPIdentityValid( hSnapshot )
            Break( NIL )
        ENDIF
        hWarmup[ MPIdentity( hSnapshot ) ] := .T.
        hSnapshot := MPSnapshot( hProfiles, cProfile )
        MPAssert( MPIdentityValid( hSnapshot ) .AND. MPStateMatches( hSnapshot, hBaseline ), ;
            "measured leases start from the same clean profile after warmup", hChecks )
        IF ! MPIdentityValid( hSnapshot )
            Break( NIL )
        ENDIF
        hBaseline := hSnapshot
        hPairs[ MPIdentity( hBaseline ) ] := .T.
        MPIdentityParts( hIdentityParts, hBaseline )
        FOR nIndex := 1 TO 12
            hSnapshot := MPSnapshot( hProfiles, cProfile )
            MPAssert( MPIdentityValid( hSnapshot ) .AND. MPStateMatches( hSnapshot, hBaseline ), ;
                "sequential connection retains profile and clean session " + hb_ntos( nIndex ), hChecks )
            IF MPIdentityValid( hSnapshot )
                hPairs[ MPIdentity( hSnapshot ) ] := .T.
                MPIdentityParts( hIdentityParts, hSnapshot )
            ENDIF
            MPAssert( Select() == nPreviousArea .AND. ;
                rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
                "query releases its logical connection and restores caller zero " + hb_ntos( nIndex ), hChecks )
        NEXT
        IF cMode == "driver"
            MPAssert( Len( hPairs ) == 1, "sequential logical leases reuse one physical connection", hChecks )
        ELSE
            MPAssert( Len( hPairs ) == 13, "pool-off control creates a distinct physical connection per lease", hChecks )
        ENDIF
        ? "MSSQL physical reuse: mode=" + cMode + "; warmupLeases=2; warmupConnections=" + ;
            hb_ntos( Len( hWarmup ) ) + "; measuredLeases=13; measuredConnections=" + hb_ntos( Len( hPairs ) )
        ? "MSSQL identity counts: ports=" + hb_ntos( Len( hIdentityParts[ "ports" ] ) ) + ;
            "; connectionIDs=" + hb_ntos( Len( hIdentityParts[ "connections" ] ) ) + ;
            "; connectionStartTimes=" + hb_ntos( Len( hIdentityParts[ "started" ] ) )

        hInfo := HBBridgeODBCPoolingInfo()
        MPAssert( hInfo[ "mode" ] == cMode .AND. hInfo[ "frozen" ], ;
            "pool mode is frozen after environment allocation", hChecks )
        MPAssert( HBBridgeODBCPooling( cMode ), "same frozen pool mode is idempotent", hChecks )
        MPAssert( ! HBBridgeODBCPooling( iif( cMode == "driver", "off", "driver" ) ) .AND. ;
            HBBridgeODBCPoolingInfo()[ "mode" ] == cMode, "changing a frozen pool mode is rejected", hChecks )

        hResult := MPQuery( hProfiles, cProfile, "SELECT FROM" )
        MPAssert( ! MPSuccess( hResult ) .AND. MPCode( hResult ) == "QUERY_FAILED", ;
            "invalid SQL returns its stable service error", hChecks )
        MPAssert( MPStateMatches( MPSnapshot( hProfiles, cProfile ), hBaseline ), ;
            "valid query recovers after invalid SQL without session contamination", hChecks )
        MPRestoration( hProfiles, cProfile, hChecks )

        MPDirtyCase( hProfiles, cProfile, hBaseline, ;
            "SET DATEFIRST " + iif( hBaseline[ "DATE_FIRST" ] == 1, "7", "1" ) + "; SET LOCK_TIMEOUT 733; " + ;
            "SET CONTEXT_INFO 0x4842425249444745504F4F4C", "settings", hChecks )
        MPDirtyCase( hProfiles, cProfile, hBaseline, ;
            "CREATE TABLE #hbbridge_pool_acceptance (ID int NOT NULL); " + ;
            "INSERT INTO #hbbridge_pool_acceptance VALUES (1)", "temporary table", hChecks )
        MPDirtyCase( hProfiles, cProfile, hBaseline, ;
            "CREATE TABLE #hbbridge_pool_acceptance (ID int NOT NULL); " + ;
            "BEGIN TRAN; INSERT INTO #hbbridge_pool_acceptance VALUES (1)", "transaction", hChecks )
        /* USE is a session mutation, never an attempt to infer ERP context.
         * Lack of access is recorded explicitly for this optional subcase.
         */
        cSwitch := iif( hBaseline[ "DATABASE_ID" ] == 1, "tempdb", "master" )
        hResult := MPQuery( hProfiles, cProfile, "SELECT CAST(HAS_DBACCESS('" + cSwitch + "') AS int) AS ALLOWED" )
        IF MPCell( hResult, "ALLOWED" ) == 1
            nSwitch := iif( cSwitch == "master", 1, 2 )
            MPDirtyCase( hProfiles, cProfile, hBaseline, "USE " + cSwitch, "database", hChecks, nSwitch )
        ELSE
            ? "MSSQL pool database-switch probe: NOT_APPLICABLE_NO_ACCESS"
        ENDIF

        hResult := MPQuery( hProfiles, "m07/pooling-slow", "WAITFOR DELAY '00:00:02'; SELECT 31 AS ID" )
        MPAssert( ! MPSuccess( hResult ) .AND. MPCode( hResult ) == "QUERY_FAILED", ;
            "one-second statement timeout survives connection reuse", hChecks )
        hResult := MPQuery( hProfiles, "m07/pooling-fast", "WAITFOR DELAY '00:00:02'; SELECT 37 AS ID" )
        MPAssert( MPSuccess( hResult ) .AND. MPCell( hResult, "ID" ) == 37, ;
            "longer statement timeout is not replaced by the previous profile timeout", hChecks )
        MPAssert( MPStateMatches( MPSnapshot( hProfiles, cProfile ), hBaseline ), ;
            "original profile recovers after timeout and timeout-profile changes", hChecks )
        MPAssert( hProfiles[ cProfile ][ "loginTimeoutSeconds" ] == 2 .AND. ;
            hProfiles[ "m07/pooling-fast" ][ "loginTimeoutSeconds" ] == 3 .AND. ;
            hProfiles[ "m07/pooling-slow" ][ "queryTimeoutSeconds" ] == 1 .AND. ;
            hProfiles[ "m07/pooling-fast" ][ "queryTimeoutSeconds" ] == 4, ;
            "normalized timeout settings remain profile-local", hChecks )

        IF HB_ISSTRING( cOtherProfile ) .AND. ! Empty( cOtherProfile )
            hOther := MPSnapshot( hProfiles, cOtherProfile )
            MPAssert( MPIdentityValid( hOther ) .AND. hOther[ "DATABASE_ID" ] != hBaseline[ "DATABASE_ID" ], ;
                "optional second profile targets a distinct database", hChecks )
            FOR nIndex := 1 TO 3
                hSnapshot := MPSnapshot( hProfiles, cProfile )
                MPAssert( MPStateMatches( hSnapshot, hBaseline ), "primary database identity remains isolated", hChecks )
                hSnapshot := MPSnapshot( hProfiles, cOtherProfile )
                MPAssert( MPStateMatches( hSnapshot, hOther ), "second database and login identity remain isolated", hChecks )
            NEXT
        ELSE
            ? "MSSQL pool second configured database: NOT_EXERCISED"
        ENDIF
        lReady := .T.
    RECOVER
        MPAssert( .F., "controlled acceptance execution completed", hChecks )
    ALWAYS
        dbSelectArea( nPreviousArea )
        MPAssert( rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
            "acceptance releases every test-owned logical connection", hChecks )
        MPAssert( HBBridgeGetPool():Status()[ "activeLeases" ] == 0, ;
            "physical reuse leaves no live service lease", hChecks )
        MPAssert( HBBridgeODBCPoolingClose() .AND. ! HBBridgeODBCPoolingInfo()[ "environmentRetained" ], ;
            "native pool releases its retained environment after all test leases close", hChecks )
    END SEQUENCE
    ? "MSSQL pooling acceptance: mode=" + cMode + "; checks=" + hb_ntos( hChecks[ "checks" ] ) + ;
        "; failures=" + hb_ntos( hChecks[ "failures" ] ) + "; elapsedMs=" + hb_ntos( HBBridgeMonotonicMs() - nStarted )

RETURN iif( lReady .AND. hChecks[ "failures" ] == 0, 0, 1 )

STATIC PROCEDURE MPRestoration( hProfiles, cProfile, hChecks )

    LOCAL hResult, hCaller, hBorrower

    LOCAL nPreviousArea := Select(), nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL nConnection := 0, nCallerArea := 0

    BEGIN SEQUENCE WITH __BreakBlock()
        nConnection := MPConnect( hProfiles[ cProfile ] )
        IF nConnection == 0
            Break( NIL )
        ENDIF
        hCaller := MPNativeSnapshot( nConnection )
        dbSelectArea( 0 )
        nCallerArea := Select()
        IF ! dbUseArea( .F., "SQLMIX", "SELECT 123 AS CALLER_ID", hb_rddGetTempAlias(), .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        hResult := MPQuery( hProfiles, cProfile, "SELECT 47 AS ID" )
        MPAssert( MPSuccess( hResult ) .AND. MPCell( hResult, "ID" ) == 47 .AND. ;
            Select() == nCallerArea .AND. FieldGet( 1 ) == 123 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "pooled query preserves the caller's nonzero connection and open workarea", hChecks )
        hResult := MPQuery( hProfiles, cProfile, "SELECT FROM" )
        MPAssert( ! MPSuccess( hResult ) .AND. Select() == nCallerArea .AND. FieldGet( 1 ) == 123 .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nConnection, ;
            "failed pooled query preserves the caller's nonzero connection and open workarea", hChecks )
        hBorrower := MPSnapshot( hProfiles, cProfile )
        MPAssert( MPIdentityValid( hCaller ) .AND. MPIdentityValid( hBorrower ) .AND. ;
            MPIdentity( hCaller ) != MPIdentity( hBorrower ), ;
            "a live caller lease cannot be assigned to the service query", hChecks )
    RECOVER
        MPAssert( .F., "caller restoration fixture completed", hChecks )
    ALWAYS
        IF nCallerArea > 0
            dbSelectArea( nCallerArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        IF nConnection > 0
            MPAssert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
                "caller fixture releases its own logical connection", hChecks )
        ENDIF
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN

STATIC PROCEDURE MPDirtyCase( hProfiles, cProfile, hBaseline, cMutation, cCase, hChecks, nDatabase )

    LOCAL hDirty, hAfter

    LOCAL lDisconnected, lMutation

    LOCAL nPreviousArea := Select(), nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL nConnection := 0

    /* No worker threads run in this fixture. Native API connection arrays and
     * direct calls belong only to this deliberately dirty test-owned lease.
     */
    BEGIN SEQUENCE WITH __BreakBlock()
        nConnection := MPConnect( hProfiles[ cProfile ] )
        IF nConnection == 0
            Break( NIL )
        ENDIF
        lMutation := rddInfo( RDDI_EXECUTE, cMutation, "SQLMIX", nConnection )
        MPAssert( lMutation, "test-owned session mutation executes: " + cCase, hChecks )
        hDirty := MPNativeSnapshot( nConnection )
        MPAssert( MPDirtyObserved( hDirty, hBaseline, cCase, nDatabase ), ;
            "session mutation is observed before return: " + cCase, hChecks )
        lDisconnected := rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
        MPAssert( lDisconnected, "dirty lease disconnect succeeds: " + cCase, hChecks )
        IF lDisconnected
            nConnection := 0
        ELSE
            Break( NIL )
        ENDIF
        hAfter := MPSnapshot( hProfiles, cProfile )
        MPAssert( MPStateMatches( hAfter, hBaseline ), "next lease has no prior session state: " + cCase, hChecks )
        IF MPIdentityValid( hAfter ) .AND. MPIdentityValid( hDirty )
            ? "MSSQL pool session probe: case=" + cCase + "; physicalConnectionReused=" + ;
                iif( MPIdentity( hAfter ) == MPIdentity( hDirty ), "true", "false" )
        ENDIF
    RECOVER
        MPAssert( .F., "session cleanup probe completed: " + cCase, hChecks )
    ALWAYS
        IF nConnection > 0
            /* Failed dirty disconnect must remain visible. This fallback is
             * test teardown, never acceptance of leaking transaction state.
             */
            rddInfo( RDDI_EXECUTE, "IF @@TRANCOUNT > 0 ROLLBACK TRAN; " + ;
                "IF OBJECT_ID('tempdb..#hbbridge_pool_acceptance') IS NOT NULL DROP TABLE #hbbridge_pool_acceptance", ;
                "SQLMIX", nConnection )
            MPAssert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
                "failed dirty lease is released during test teardown: " + cCase, hChecks )
        ENDIF
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN

STATIC FUNCTION MPDirtyObserved( hDirty, hBaseline, cCase, nDatabase )

    IF ! MPIdentityValid( hDirty )
        RETURN .F.
    ENDIF
    DO CASE
    CASE cCase == "settings"
        RETURN hDirty[ "DATE_FIRST" ] != hBaseline[ "DATE_FIRST" ] .AND. ;
            hDirty[ "LOCK_TIMEOUT" ] == 733 .AND. hDirty[ "CONTEXT_PRESENT" ] == 1
    CASE cCase == "temporary table"
        RETURN hDirty[ "TEMP_PRESENT" ] == 1
    CASE cCase == "transaction"
        RETURN hDirty[ "TRAN_COUNT" ] == 1 .AND. hDirty[ "XACT_STATE" ] == 1 .AND. hDirty[ "TEMP_PRESENT" ] == 1
    CASE cCase == "database"
        RETURN hDirty[ "DATABASE_ID" ] == nDatabase .AND. nDatabase != hBaseline[ "DATABASE_ID" ]
    ENDCASE

RETURN .F.

STATIC FUNCTION MPConnect( hProfile )

    /* The native RDD contract requires these positional connection slots. */
RETURN rddInfo( RDDI_CONNECT, { "ODBC", hProfile[ "connectionString" ], ;
    hb_HGetDef( hProfile, "loginTimeoutSeconds", NIL ), ;
    hb_HGetDef( hProfile, "queryTimeoutSeconds", NIL ) }, "SQLMIX" )

STATIC FUNCTION MPNativeSnapshot( nConnection )

    LOCAL hSnapshot

    LOCAL nPreviousArea, nQueryArea, nField

    nPreviousArea := Select()
    nQueryArea := 0
    hSnapshot := NIL

    BEGIN SEQUENCE WITH __BreakBlock()
        dbSelectArea( 0 )
        nQueryArea := Select()
        IF dbUseArea( .F., "SQLMIX", MPSnapshotSQL(), hb_rddGetTempAlias(), .T., .T., NIL, nConnection ) .AND. ! Eof()
            hSnapshot := {=>}
            FOR nField := 1 TO FCount()
                hSnapshot[ Upper( AllTrim( FieldName( nField ) ) ) ] := FieldGet( nField )
            NEXT
        ENDIF
    RECOVER
        hSnapshot := NIL
    ALWAYS
        IF nQueryArea > 0
            dbSelectArea( nQueryArea )
            IF Used()
                dbCloseArea()
            ENDIF
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN hSnapshot

STATIC FUNCTION MPSnapshot( hProfiles, cProfile )

    LOCAL hResult := MPQuery( hProfiles, cProfile, MPSnapshotSQL() )

    IF MPSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1
        RETURN hResult[ "rows" ][ "1" ]
    ENDIF

RETURN NIL

STATIC FUNCTION MPSnapshotSQL()
RETURN "SELECT CAST(@@SPID AS int) AS SESSION_ID, CAST(c.client_tcp_port AS int) AS CLIENT_PORT, " + ;
    "CONVERT(varchar(36),c.connection_id) AS PHYSICAL_ID, " + ;
    "CAST(c.net_transport AS varchar(40)) AS TRANSPORT, " + ;
    "CONVERT(varchar(33),c.connect_time,126) AS CONNECTION_STARTED, " + ;
    "CAST(DB_ID() AS int) AS DATABASE_ID, CAST(SUSER_ID() AS int) AS LOGIN_ID, " + ;
    "CAST(@@TRANCOUNT AS int) AS TRAN_COUNT, CAST(XACT_STATE() AS int) AS XACT_STATE, " + ;
    "CAST(@@DATEFIRST AS int) AS DATE_FIRST, CAST(@@LOCK_TIMEOUT AS int) AS LOCK_TIMEOUT, " + ;
    "CASE WHEN OBJECT_ID('tempdb..#hbbridge_pool_acceptance') IS NULL THEN 0 ELSE 1 END AS TEMP_PRESENT, " + ;
    "CASE WHEN CONTEXT_INFO() = 0x4842425249444745504F4F4C THEN 1 ELSE 0 END AS CONTEXT_PRESENT " + ;
    "FROM sys.dm_exec_connections AS c WHERE c.session_id = @@SPID AND c.parent_connection_id IS NULL"

STATIC FUNCTION MPIdentityValid( hSnapshot )

    LOCAL hFields := { "SESSION_ID" => .T., "CLIENT_PORT" => .T., "CONNECTION_STARTED" => .T., "PHYSICAL_ID" => .T., ;
        "TRANSPORT" => .T., "DATABASE_ID" => .T., "LOGIN_ID" => .T., "TRAN_COUNT" => .T., ;
        "XACT_STATE" => .T., "DATE_FIRST" => .T., "LOCK_TIMEOUT" => .T., ;
        "TEMP_PRESENT" => .T., "CONTEXT_PRESENT" => .T. }

    LOCAL lField

    IF ! HB_ISHASH( hSnapshot )
        RETURN .F.
    ENDIF
    FOR EACH lField IN hFields
        IF ! hb_HHasKey( hSnapshot, lField:__enumKey() )
            RETURN .F.
        ENDIF
    NEXT

RETURN ;
    HB_ISNUMERIC( hSnapshot[ "SESSION_ID" ] ) .AND. hSnapshot[ "SESSION_ID" ] > 0 .AND. ;
    HB_ISSTRING( hSnapshot[ "PHYSICAL_ID" ] ) .AND. Len( AllTrim( hSnapshot[ "PHYSICAL_ID" ] ) ) == 36 .AND. ;
    HB_ISSTRING( hSnapshot[ "CONNECTION_STARTED" ] ) .AND. ! Empty( hSnapshot[ "CONNECTION_STARTED" ] ) .AND. ;
    HB_ISSTRING( hSnapshot[ "TRANSPORT" ] ) .AND. ! Empty( hSnapshot[ "TRANSPORT" ] ) .AND. ;
    ( AllTrim( hSnapshot[ "TRANSPORT" ] ) != "TCP" .OR. ;
        ( HB_ISNUMERIC( hSnapshot[ "CLIENT_PORT" ] ) .AND. hSnapshot[ "CLIENT_PORT" ] > 0 ) )

STATIC FUNCTION MPIdentity( hSnapshot )
RETURN hSnapshot[ "PHYSICAL_ID" ] + ":" + hb_ntos( hSnapshot[ "SESSION_ID" ] ) + ":" + ;
    hSnapshot[ "CONNECTION_STARTED" ]

STATIC PROCEDURE MPIdentityParts( hParts, hSnapshot )
    hParts[ "ports" ][ hb_Serialize( hSnapshot[ "CLIENT_PORT" ] ) ] := .T.
    hParts[ "connections" ][ hSnapshot[ "PHYSICAL_ID" ] ] := .T.
    hParts[ "started" ][ hSnapshot[ "CONNECTION_STARTED" ] ] := .T.
RETURN

STATIC FUNCTION MPStateMatches( hSnapshot, hBaseline )

    LOCAL cField

    LOCAL hFields := { "DATABASE_ID" => .T., "LOGIN_ID" => .T., "TRAN_COUNT" => .T., ;
        "XACT_STATE" => .T., "DATE_FIRST" => .T., "LOCK_TIMEOUT" => .T., ;
        "TEMP_PRESENT" => .T., "CONTEXT_PRESENT" => .T. }

    LOCAL lField

    IF ! MPIdentityValid( hSnapshot ) .OR. ! MPIdentityValid( hBaseline )
        RETURN .F.
    ENDIF
    FOR EACH lField IN hFields
        cField := lField:__enumKey()
        IF ! hb_HHasKey( hSnapshot, cField ) .OR. hSnapshot[ cField ] != hBaseline[ cField ]
            RETURN .F.
        ENDIF
    NEXT

RETURN .T.

STATIC FUNCTION MPQuery( hProfiles, cProfile, cSQL )
RETURN HBBridgeSQLQuery( { "alias" => cProfile, "sql" => cSQL }, hProfiles )

STATIC FUNCTION MPSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "success" ) .AND. hResult[ "success" ] == .T.

STATIC FUNCTION MPCell( hResult, cField )

    IF MPSuccess( hResult ) .AND. hResult[ "rowCount" ] == 1 .AND. ;
        hb_HHasKey( hResult[ "rows" ][ "1" ], cField )
        RETURN hResult[ "rows" ][ "1" ][ cField ]
    ENDIF

RETURN NIL

STATIC FUNCTION MPCode( hResult )

    IF HB_ISHASH( hResult ) .AND. hb_HHasKey( hResult, "code" ) .AND. hResult[ "code" ] == "QUERY_FAILED"
        RETURN "QUERY_FAILED"
    ENDIF

RETURN "UNEXPECTED_SAFE_CODE"

STATIC PROCEDURE MPAssert( lCondition, cLabel, hChecks )

    hChecks[ "checks" ]++
    IF lCondition
        ? "PASS:", cLabel
    ELSE
        hChecks[ "failures" ]++
        ? "FAIL:", cLabel
    ENDIF

RETURN
