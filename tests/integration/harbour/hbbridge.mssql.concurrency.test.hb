/* Released to Public Domain. */
#include "dbinfo.ch"
#include "hbsocket.ch"

REQUEST HB_CODEPAGE_UTF8EX

/* Opt-in M07 acceptance. The real MSSQL database receives constant SELECTs
 * only. SQLite writes belong to a unique disposable test-run directory.
 * Eight callers contend for the existing shared SQL lifecycle mutex; this
 * proves isolation and release, not simultaneous SQL execution or speed.
 */
PROCEDURE MSSQLConcurrencyTests( cConfigPath, cProfile, cMode, cBacklog, cPooling )

    LOCAL nExit := 1, cPreviousCodepage := hb_cdpSelect()

    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile )
        ? "MSSQL concurrency prerequisite: CONFIG_AND_PROFILE_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        nExit := MCRun( cConfigPath, cProfile, cMode, cBacklog, cPooling )
    RECOVER
        ? "MSSQL concurrency acceptance: UNEXPECTED_RUNTIME_ERROR"
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE
    ErrorLevel( nExit )

RETURN

STATIC FUNCTION MCRun( cConfigPath, cProfile, cMode, cBacklog, cPooling )

    LOCAL hChecks := { "checks" => 0, "failures" => 0 }, hPrivate, hProfiles, hRegistry
    LOCAL hConfig := NIL, hHost := NIL, hWorking, cError, hResult, hProbes := {=>}
    LOCAL hWorkers := {=>}, hWorker, hJoined := {=>}, hReady := {=>}, nIndex, nWorker
    LOCAL nPreviousArea := Select(), nPreviousConnection := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" )
    LOCAL cDatabase := HBBridgeAbsolutePath( "m07-concurrency.sqlite3", hb_cwd() )
    LOCAL hGate := { "ready" => hb_mutexCreate() }, lReady := .F., lCheck, nKey, nConnection := 0
    LOCAL hFixture, hRoutes := { 1 => "local", 2 => "NETIO", 3 => "TCP", 4 => "HTTP" }
    LOCAL hSettings, hBeforeSlots := NIL, hAfterSlots := NIL, nStarted, nElapsed, lNETIOConnected := .F.

    hPrivate := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
    IF hPrivate == NIL .OR. ! hb_HHasKey( hPrivate[ "sqlProfiles" ], cProfile ) .OR. ;
        cProfile == "m07/sqlite" .OR. cProfile == "m07/mssql-clone"
        ? "MSSQL concurrency prerequisite: PROFILE_INVALID"
        RETURN 2
    ENDIF
    hWorking := hb_HClone( hPrivate[ "sqlProfiles" ][ cProfile ] )
    IF hWorking[ "driver" ] != "mssql" .OR. ! hb_mtvm()
        ? "MSSQL concurrency prerequisite: MSSQL_AND_MULTITHREAD_RUNTIME_REQUIRED"
        RETURN 2
    ENDIF
    IF HB_ISSTRING( cPooling ) .AND. ! Empty( cPooling )
        hSettings := HBBridgeConfig( { "-odbcpooling=" + cPooling }, @cError )
        IF hSettings == NIL
            ? "MSSQL concurrency prerequisite: ODBC_POOLING_INVALID"
            RETURN 2
        ENDIF
        hPrivate[ "sqlODBCPooling" ] := hSettings[ "sqlODBCPooling" ]
    ENDIF
    IF ! HBBridgeSQLConfigure( hPrivate[ "sqlODBCPooling" ], @cError )
        ? "MSSQL concurrency prerequisite: ODBC_POOLING_UNAVAILABLE"
        RETURN 2
    ENDIF
    hWorking[ "loginTimeoutSeconds" ] := 2
    hWorking[ "queryTimeoutSeconds" ] := 5
    hProfiles := HBBridgeSQLProfiles( { cProfile => hWorking, ;
        "m07/mssql-clone" => hb_HClone( hWorking ), ;
        "m07/sqlite" => { "driver" => "sqlite", "database" => cDatabase } }, hb_cwd(), @cError )
    IF hProfiles == NIL
        ? "MSSQL concurrency prerequisite: TEST_PROFILE_INVALID"
        RETURN 2
    ENDIF
    hRegistry := HBBridgeBuiltinRegistry( hProfiles )
    hFixture := { 1 => { "alias" => cProfile, "driver" => "mssql", "field" => "MSSQL_ONLY", ;
            "value" => "primary", "sql" => MCConstantSQL( "MSSQL_ONLY", "primary" ) }, ;
        2 => { "alias" => "m07/mssql-clone", "driver" => "mssql", "field" => "CLONE_ONLY", ;
            "value" => "clone", "sql" => MCConstantSQL( "CLONE_ONLY", "clone" ) }, ;
        3 => { "alias" => "m07/sqlite", "driver" => "sqlite", "field" => "SQLITE_ONLY", ;
            "value" => "sqlite", "sql" => "SELECT ID, SQLITE_ONLY FROM m07_fixture" } }
    BEGIN SEQUENCE WITH __BreakBlock()
        /* Positional arrays are required by native RDDI_CONNECT. This setup
         * runs before threads start; credentials remain inside hProfiles.
         */
        nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
        IF nConnection == 0 .OR. ;
            ! rddInfo( RDDI_EXECUTE, "CREATE TABLE m07_fixture (ID INTEGER, SQLITE_ONLY TEXT)", "SQLMIX", nConnection ) .OR. ;
            ! rddInfo( RDDI_EXECUTE, "INSERT INTO m07_fixture VALUES " + ;
                "(1,'sqlite'),(2,'sqlite'),(3,'sqlite'),(4,'sqlite'),(5,'sqlite')", "SQLMIX", nConnection )
            ? "MSSQL concurrency prerequisite: SQLITE_FIXTURE_FAILED"
            Break( NIL )
        ENDIF
        MCAssert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ), ;
            "isolated SQLite fixture connection released", hChecks )
        nConnection := 0
        FOR EACH hResult IN hFixture
            MCAssert( MCData( MCQuery( hRegistry, { "alias" => hResult[ "alias" ], ;
                "sql" => hResult[ "sql" ] } ), hResult, 1, 5 ), ;
                "baseline schema and values: " + hResult[ "driver" ] + "/" + hResult[ "value" ], hChecks )
        NEXT
        IF hChecks[ "failures" ] > 0
            ? "MSSQL concurrency prerequisite: BASELINE_QUERY_FAILED"
            Break( NIL )
        ENDIF
        hConfig := HBBridgeConfig( {} )
        hConfig[ "protheusHost" ] := "127.0.0.1"
        hConfig[ "protheusPort" ] := 0
        hConfig[ "protheusTimeoutMs" ] := 15000
        hConfig[ "maxWorkers" ] := hPrivate[ "maxWorkers" ]
        hConfig[ "sqlODBCPooling" ] := hPrivate[ "sqlODBCPooling" ]
        hConfig[ "httpListenBacklog" ] := hPrivate[ "httpListenBacklog" ]
        hConfig[ "netioHost" ] := "127.0.0.1"
        hConfig[ "netioPort" ] := MCFreePort()
        hConfig[ "netioPassword" ] := "m07-netio-test-only"
        hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "m07-netio", hb_cwd() )
        IF HB_ISSTRING( cBacklog ) .AND. ! Empty( cBacklog ) .AND. cBacklog != "native"
            hSettings := HBBridgeConfig( { "-httplistenbacklog=" + cBacklog }, @cError )
            IF hSettings == NIL
                ? "MSSQL concurrency prerequisite: HTTP_BACKLOG_INVALID"
                Break( NIL )
            ENDIF
            hConfig[ "httpListenBacklog" ] := hSettings[ "httpListenBacklog" ]
        ENDIF
        hConfig[ "httpEnabled" ] := .T.
        hConfig[ "httpHost" ] := "127.0.0.1"
        hConfig[ "httpPort" ] := MCFreePort()
        hConfig[ "httpPassword" ] := "m07-http-test-only"
        hConfig[ "sqlProfiles" ] := hProfiles
        hHost := HBBridgeHostStart( hConfig, @cError )
        IF hHost == NIL
            ? "MSSQL concurrency prerequisite: ISOLATED_HOST_FAILED"
            Break( NIL )
        ENDIF
        /* netio_GetConnection borrows reference-counted pointers from a process
         * endpoint cache. Keep one explicit parent connection until all workers
         * release their borrowed pointers; endpoint Disconnect belongs here.
         */
        lNETIOConnected := netio_Connect( "127.0.0.1", hConfig[ "netioPort" ], 15000, "m07-netio-test-only" )
        MCAssert( lNETIOConnected, "parent owns the native NETIO endpoint cache reference", hChecks )
        IF ! lNETIOConnected
            Break( NIL )
        ENDIF
        hSettings := { "registry" => hRegistry, "fixtures" => hFixture, "gate" => hGate, ;
            "tcpPort" => hHost[ "listeners" ][ "protheus" ][ "port" ], ;
            "netioPort" => hConfig[ "netioPort" ], "httpPort" => hConfig[ "httpPort" ] }
        /* Reserve caller handles before workers start. Each worker creates
         * and closes only its own workarea. Root disconnects after join: a
         * leaked caller area makes native RDDI_DISCONNECT fail.
         */
        FOR nIndex := 1 TO 8
            nConnection := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
            IF nConnection == 0
                ? "MSSQL concurrency prerequisite: CALLER_CONNECTION_FAILED"
                Break( NIL )
            ENDIF
            hWorkers[ hb_ntos( nIndex ) ] := { "index" => nIndex, "route" => Int( ( nIndex - 1 ) / 2 ) + 1, ;
                "connection" => nConnection, "release" => hb_mutexCreate(), "thread" => NIL }
            nConnection := 0
        NEXT
        hBeforeSlots := MCSlots( cDatabase, hWorking, hProbes )
        MCAssert( hBeforeSlots != NIL, "native connection-slot baseline acquired and released", hChecks )
        IF hBeforeSlots == NIL
            Break( NIL )
        ENDIF
        nStarted := HBBridgeMonotonicMs()
        FOR EACH hWorker IN hWorkers
            hWorker[ "thread" ] := hb_threadStart( 0, @MCWorker(), hSettings, hWorker )
            IF Empty( hWorker[ "thread" ] )
                Break( NIL )
            ENDIF
        NEXT
        FOR nIndex := 1 TO Len( hWorkers )
            nWorker := NIL
            IF ! hb_mutexSubscribe( hGate[ "ready" ], 20, @nWorker ) .OR. ! HB_ISNUMERIC( nWorker )
                Break( NIL )
            ENDIF
            hReady[ hb_ntos( nWorker ) ] := .T.
        NEXT
        MCAssert( Len( hReady ) == 8, "all eight workers reach the synchronized start barrier", hChecks )
        FOR EACH hWorker IN hWorkers
            hb_mutexNotify( hWorker[ "release" ], .T. )
        NEXT
        FOR EACH hWorker IN hWorkers
            hResult := NIL
            MCAssert( hb_threadJoin( hWorker[ "thread" ], @hResult ), ;
                "worker joins: " + hRoutes[ hWorker[ "route" ] ] + "/" + hWorker:__enumKey(), hChecks )
            hJoined[ hWorker:__enumKey() ] := .T.
            MCAssert( HB_ISHASH( hResult ), "worker returns its owned result hash: " + hWorker:__enumKey(), hChecks )
            IF HB_ISHASH( hResult )
                FOR EACH lCheck IN hResult
                    MCAssert( lCheck, hRoutes[ hWorker[ "route" ] ] + " worker " + ;
                        hWorker:__enumKey() + ": " + lCheck:__enumKey(), hChecks )
                NEXT
            ENDIF
        NEXT
        nElapsed := HBBridgeMonotonicMs() - nStarted
        hAfterSlots := MCSlots( cDatabase, hWorking, hProbes )
        MCAssert( hAfterSlots != NIL .AND. hAfterSlots[ "sqlite" ] == hBeforeSlots[ "sqlite" ] .AND. ;
            hAfterSlots[ "mssql" ] == hBeforeSlots[ "mssql" ], ;
            "both native connection slots reused after all worker success/failure rounds", hChecks )
        FOR EACH hResult IN hFixture
            MCAssert( MCData( MCQuery( hRegistry, { "alias" => hResult[ "alias" ], ;
                "sql" => hResult[ "sql" ] } ), hResult, 1, 5 ), ;
                "profile recovers after all concurrent callers: " + hResult[ "value" ], hChecks )
        NEXT
        lReady := .T.
        ? "Concurrency fixture: workers=8; rounds=3; routes=local/NETIO/TCP/HTTP; calls=192; elapsed ms:", nElapsed
        IF cMode == "serve" .AND. hChecks[ "failures" ] == 0
            ? "M07 TCP port:", hSettings[ "tcpPort" ], "HTTP port:", hSettings[ "httpPort" ]
            ? "M07 HTTP workers:", hConfig[ "maxWorkers" ], "listen backlog:", hConfig[ "httpListenBacklog" ]
            ? "M07 profiles:", cProfile, "m07/mssql-clone", "m07/sqlite"
            ? "M07 HTTP test token: m07-http-test-only"
            ? "M07 isolated validation host ready for 600 seconds; create m07.stop in this run directory to stop."
            nStarted := HBBridgeMonotonicMs()
            DO WHILE HBBridgeMonotonicMs() - nStarted < 600000 .AND. ! hb_FileExists( "m07.stop" )
                nKey := Inkey( 0.1 )
                IF nKey == 27 .OR. nKey == 17
                    EXIT
                ENDIF
            ENDDO
        ENDIF
    RECOVER
        ? "MSSQL concurrency acceptance: CONTROLLED_SETUP_OR_WORKER_FAILURE"
    ALWAYS
        /* Never detach a live SQL worker. Release failed setup barriers, join
         * every owned thread, then disconnect caller handles and stop host.
         */
        FOR EACH hWorker IN hWorkers
            IF ! Empty( hWorker[ "thread" ] ) .AND. ! hb_HHasKey( hJoined, hWorker:__enumKey() )
                hb_mutexNotify( hWorker[ "release" ], .F. )
                MCAssert( hb_threadJoin( hWorker[ "thread" ] ), "unfinished worker joined during cleanup", hChecks )
            ENDIF
            MCAssert( rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", hWorker[ "connection" ] ), ;
                "caller native connection released after area cleanup: " + hWorker:__enumKey(), hChecks )
        NEXT
        IF nConnection > 0
            rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
        ENDIF
        FOR EACH nConnection IN hProbes
            IF nConnection > 0
                rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
            ENDIF
        NEXT
        IF lNETIOConnected
            MCAssert( netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] ), ;
                "parent releases NETIO endpoint after all borrowed worker pointers", hChecks )
            MCAssert( ! netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] ), ;
                "NETIO endpoint cache retains no pointer after owner release", hChecks )
        ENDIF
        IF hHost != NIL
            MCAssert( HBBridgeHostStop( hHost ), "isolated host stops and joins its owned listeners/workers", hChecks )
            MCAssert( MCListenersClosed( hHost ), "all isolated host listeners report stopped and zero active workers", hChecks )
        ENDIF
        IF nPreviousConnection > 0
            rddInfo( RDDI_CONNECTION, nPreviousConnection, "SQLMIX" )
        ENDIF
        dbSelectArea( nPreviousArea )
        MCAssert( Select() == nPreviousArea .AND. ;
            rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) == nPreviousConnection, ;
            "root caller area and default connection restored after cleanup", hChecks )
    END SEQUENCE
    ? "MSSQL concurrency checks:", hChecks[ "checks" ], "failures:", hChecks[ "failures" ], "skips: 0"

RETURN iif( ! lReady, 2, iif( hChecks[ "failures" ] == 0, 0, 1 ) )

STATIC FUNCTION MCWorker( hSettings, hWorker )

    LOCAL hChecks := {=>}, nCallerArea := 0, nPreviousArea := Select(), cCallerAlias
    LOCAL nConnection := hWorker[ "connection" ], nIndex := hWorker[ "index" ], nRound, nFixture
    LOCAL hFixture, hParams, hResponse, hResult, hSnapshot, cPrefix, lRelease := .F., pNative := NIL
    LOCAL nCalls := 0, nMarker, cRecoverySQL, hRoutes := { 1 => "local", 2 => "NETIO", 3 => "TCP", 4 => "HTTP" }

    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        rddInfo( RDDI_CONNECTION, nConnection, "SQLMIX" )
        dbSelectArea( 0 )
        nCallerArea := Select()
        cCallerAlias := hb_rddGetTempAlias()
        IF ! dbUseArea( .F., "SQLMIX", "SELECT " + hb_ntos( nIndex ) + " AS CALLER_ID", ;
            cCallerAlias, .T., .T., NIL, nConnection )
            Break( NIL )
        ENDIF
        hChecks[ "native caller fixture remains readable" ] := FieldGet( 1 ) == nIndex
        IF hWorker[ "route" ] == 2
            pNative := netio_GetConnection( "127.0.0.1", hSettings[ "netioPort" ], 15000, "m07-netio-test-only" )
            hChecks[ "worker owns its NETIO client connection" ] := ! Empty( pNative )
            IF Empty( pNative )
                Break( NIL )
            ENDIF
        ENDIF
        hb_mutexNotify( hSettings[ "gate" ][ "ready" ], nIndex )
        hChecks[ "synchronized start released" ] := hb_mutexSubscribe( hWorker[ "release" ], 30, @lRelease ) .AND. lRelease
        IF ! lRelease
            Break( NIL )
        ENDIF
        FOR nRound := 1 TO 3
            nFixture := Mod( nIndex + nRound - 2, 3 ) + 1
            hFixture := hSettings[ "fixtures" ][ nFixture ]
            cPrefix := "round " + hb_ntos( nRound ) + " " + hFixture[ "value" ] + ": "
            hParams := { "alias" => hFixture[ "alias" ], "sql" => hFixture[ "sql" ] }
            hSnapshot := MCSnapshot()
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, hParams )
            nCalls++
            hChecks[ cPrefix + "unpaged schema/driver/rows contain only the selected fixture" ] := ;
                MCResponseData( hResponse, hFixture, 1, 5 )
            hChecks[ cPrefix + "unpaged restores all caller workareas/default connection" ] := MCState( hSnapshot, nIndex )
            hParams[ "page" ] := { "number" => 1, "size" => 2, "orderBy" => "ID" }
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, hParams )
            nCalls++
            hChecks[ cPrefix + "first page and independent count match the selected fixture" ] := ;
                MCResponseData( hResponse, hFixture, 1, 2 ) .AND. MCPage( hResponse[ "result" ], 1, .T. )
            hChecks[ cPrefix + "page/count restore all caller workareas/default connection" ] := MCState( hSnapshot, nIndex )
            hParams[ "page" ][ "number" ] := 3
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, hParams )
            nCalls++
            hChecks[ cPrefix + "final page preserves exact totals and schema" ] := ;
                MCResponseData( hResponse, hFixture, 5, 1 ) .AND. MCPage( hResponse[ "result" ], 3, .F. )
            hChecks[ cPrefix + "final page restores caller state" ] := MCState( hSnapshot, nIndex )
            hParams[ "page" ][ "number" ] := 4
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, hParams )
            nCalls++
            hChecks[ cPrefix + "empty page keeps schema and actual totals without stale rows" ] := ;
                MCResponseData( hResponse, hFixture, 0, 0 ) .AND. MCPage( hResponse[ "result" ], 4, .F. )
            hChecks[ cPrefix + "empty page restores caller state" ] := MCState( hSnapshot, nIndex )
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, ;
                { "alias" => hFixture[ "alias" ], "sql" => "SELECT FROM" } )
            nCalls++
            hChecks[ cPrefix + "failed OPEN has a safe envelope without partial rows" ] := MCSafeFailure( hResponse, "QUERY_FAILED" )
            hChecks[ cPrefix + "failed OPEN restores caller state" ] := MCState( hSnapshot, nIndex )
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, ;
                { "alias" => hFixture[ "alias" ], "sql" => "SELECT 1 AS DUPLICATE_ID, 2 AS DUPLICATE_ID" } )
            nCalls++
            hChecks[ cPrefix + "ambiguous columns reject rather than leaking earlier schema" ] := ;
                MCSafeFailure( hResponse, "AMBIGUOUS_COLUMN" )
            hChecks[ cPrefix + "ambiguous column cleanup restores caller state" ] := MCState( hSnapshot, nIndex )
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, ;
                { "alias" => "__HBBridgeM07UnknownProfile__", "sql" => "SELECT 1" } )
            nCalls++
            hChecks[ cPrefix + "unknown profile cannot fall back to another caller profile" ] := ;
                MCSafeFailure( hResponse, "PROFILE_NOT_FOUND" )
            hChecks[ cPrefix + "unknown profile preserves caller state" ] := MCState( hSnapshot, nIndex )
            nMarker := nIndex * 100 + nRound
            cRecoverySQL := "SELECT " + hb_ntos( nMarker ) + " AS WORKER_VALUE, '" + ;
                hRoutes[ hWorker[ "route" ] ] + "' AS WORKER_ROUTE"
            hResponse := MCCall( hWorker[ "route" ], hSettings, pNative, ;
                { "alias" => hFixture[ "alias" ], "sql" => cRecoverySQL } )
            nCalls++
            hResult := hResponse[ "result" ]
            hChecks[ cPrefix + "recovery returns only this worker/round marker" ] := ;
                MCSuccess( hResult ) .AND. hResponse[ "status" ] == 200 .AND. ;
                hResult[ "driver" ] == hFixture[ "driver" ] .AND. Len( hResult[ "header" ] ) == 2 .AND. ;
                hResult[ "rowCount" ] == 1 .AND. MCCell( hResult, 1, "WORKER_VALUE" ) == nMarker .AND. ;
                MCCell( hResult, 1, "WORKER_ROUTE" ) == hRoutes[ hWorker[ "route" ] ]
            hChecks[ cPrefix + "recovery restores caller state" ] := MCState( hSnapshot, nIndex )
        NEXT
        hChecks[ "all 24 service calls completed" ] := nCalls == 24
    RECOVER
        hChecks[ "worker completes without a runtime error" ] := .F.
    ALWAYS
        IF pNative != NIL
            /* Drop only this worker's borrowed GC reference. The parent owns
             * the endpoint-level netio_Connect/netio_Disconnect lifecycle.
             */
            pNative := NIL
        ENDIF
        IF nCallerArea > 0
            dbSelectArea( nCallerArea )
            IF Used()
                dbCloseArea()
            ENDIF
            hChecks[ "owned caller workarea closes" ] := ! Used()
        ENDIF
        dbSelectArea( nPreviousArea )
    END SEQUENCE

RETURN hChecks

STATIC FUNCTION MCConstantSQL( cField, cValue )
    LOCAL nRow, cSQL := ""
    FOR nRow := 1 TO 5
        cSQL += iif( nRow > 1, " UNION ALL ", "" ) + "SELECT " + hb_ntos( nRow ) + ;
            " AS ID, '" + cValue + "' AS " + cField
    NEXT
RETURN cSQL

STATIC FUNCTION MCSlots( cDatabase, hWorking, hProbes )
    LOCAL hSlots := NIL, lReleased := .T., nConnection
    hProbes[ "sqlite" ] := 0
    hProbes[ "mssql" ] := 0
    BEGIN SEQUENCE WITH __BreakBlock()
        hProbes[ "sqlite" ] := rddInfo( RDDI_CONNECT, { "SQLITE3", cDatabase }, "SQLMIX" )
        hProbes[ "mssql" ] := rddInfo( RDDI_CONNECT, { "ODBC", hWorking[ "connectionString" ], 2, 5 }, "SQLMIX" )
        IF hProbes[ "sqlite" ] > 0 .AND. hProbes[ "mssql" ] > 0
            hSlots := hb_HClone( hProbes )
        ENDIF
    ALWAYS
        FOR EACH nConnection IN hProbes
            IF nConnection > 0
                lReleased := rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection ) .AND. lReleased
                nConnection := 0
            ENDIF
        NEXT
    END SEQUENCE
RETURN iif( lReleased, hSlots, NIL )

STATIC FUNCTION MCSnapshot()
    LOCAL hAreas := {=>}, nSelected := Select(), nFree
    hb_WAEval( {|| hAreas[ hb_ntos( Select() ) ] := Alias(), .T. } )
    dbSelectArea( 0 )
    nFree := Select()
    dbSelectArea( nSelected )
RETURN { "areas" => hAreas, "selected" => nSelected, "free" => nFree, ;
    "connection" => rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ) }

STATIC FUNCTION MCState( hBefore, nMarker )
    LOCAL hAfter := MCSnapshot(), cAlias
    IF hAfter[ "selected" ] != hBefore[ "selected" ] .OR. hAfter[ "free" ] != hBefore[ "free" ] .OR. ;
        hAfter[ "connection" ] != hBefore[ "connection" ] .OR. Len( hAfter[ "areas" ] ) != Len( hBefore[ "areas" ] )
        RETURN .F.
    ENDIF
    FOR EACH cAlias IN hBefore[ "areas" ]
        IF hb_HGetDef( hAfter[ "areas" ], cAlias:__enumKey(), NIL ) != cAlias
            RETURN .F.
        ENDIF
    NEXT
RETURN Used() .AND. FieldGet( 1 ) == nMarker

STATIC FUNCTION MCQuery( hRegistry, hParams )
RETURN HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, HBBridgeContext( "m07" ) )

STATIC FUNCTION MCCall( nRoute, hSettings, pNative, hParams )
    LOCAL hResult, hHTTP
    DO CASE
    CASE nRoute == 1
        hResult := MCQuery( hSettings[ "registry" ], hParams )
    CASE nRoute == 2
        hResult := netio_FuncExec( pNative, "HBBridge.Call", "RPCRDD.Query", hParams )
    CASE nRoute == 3
        hResult := MCTCP( hSettings[ "tcpPort" ], hParams )
    OTHERWISE
        hHTTP := HBBridgeHTTPTestRequest( hSettings[ "httpPort" ], "POST", "/api/v1/rpc", ;
            hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } ), "Bearer m07-http-test-only" )
        RETURN { "result" => hHTTP[ "json" ], "status" => hHTTP[ "status" ] }
    ENDCASE
RETURN { "result" => hResult, "status" => iif( MCSuccess( hResult ), 200, 500 ) }

STATIC FUNCTION MCTCP( nPort, hParams )
    LOCAL hSocket := hb_socketOpen(), cReply, hResult := NIL
    LOCAL hPolicy := { "protheusTimeoutMs" => 15000 }
    BEGIN SEQUENCE WITH __BreakBlock()
        IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 15000 ) .AND. ;
            SendResponse( hSocket, hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } ), hPolicy ) .AND. ;
            ReceiveRequest( hSocket, @cReply, hPolicy )
            hb_jsonDecode( cReply, @hResult )
        ENDIF
    ALWAYS
        hb_socketClose( hSocket )
    END SEQUENCE
RETURN hResult

STATIC FUNCTION MCSuccess( hResult )
RETURN HB_ISHASH( hResult ) .AND. hb_HGetDef( hResult, "success", .F. ) == .T. .AND. ;
    HB_ISHASH( hb_HGetDef( hResult, "header", NIL ) ) .AND. HB_ISHASH( hb_HGetDef( hResult, "rows", NIL ) )

STATIC FUNCTION MCCell( hResult, nRow, cField )
    LOCAL hRow := hb_HGetDef( hb_HGetDef( hResult, "rows", {=>} ), hb_ntos( nRow ), NIL )
RETURN iif( HB_ISHASH( hRow ), hb_HGetDef( hRow, cField, NIL ), NIL )

STATIC FUNCTION MCData( hResult, hFixture, nFirst, nRows )
    LOCAL hRow, nRow
    IF ! MCSuccess( hResult ) .OR. hb_HGetDef( hResult, "driver", "" ) != hFixture[ "driver" ] .OR. ;
        hb_HGetDef( hResult, "rowCount", -1 ) != nRows .OR. Len( hResult[ "header" ] ) != 2 .OR. ;
        ! hb_HHasKey( hResult[ "header" ], "ID" ) .OR. ! hb_HHasKey( hResult[ "header" ], hFixture[ "field" ] ) .OR. ;
        Len( hResult[ "rows" ] ) != nRows
        RETURN .F.
    ENDIF
    FOR nRow := 1 TO nRows
        hRow := hb_HGetDef( hResult[ "rows" ], hb_ntos( nRow ), NIL )
        IF ! HB_ISHASH( hRow ) .OR. Len( hRow ) != 2 .OR. ;
            hb_HGetDef( hRow, "ID", NIL ) != nFirst + nRow - 1 .OR. ;
            hb_HGetDef( hRow, hFixture[ "field" ], NIL ) != hFixture[ "value" ]
            RETURN .F.
        ENDIF
    NEXT
RETURN hResult[ "header" ][ "ID" ][ "position" ] == 1 .AND. ;
    hResult[ "header" ][ hFixture[ "field" ] ][ "position" ] == 2

STATIC FUNCTION MCResponseData( hResponse, hFixture, nFirst, nRows )
RETURN hResponse[ "status" ] == 200 .AND. MCData( hResponse[ "result" ], hFixture, nFirst, nRows )

STATIC FUNCTION MCPage( hResult, nNumber, lHasNext )
    IF ! MCSuccess( hResult ) .OR. ! HB_ISHASH( hb_HGetDef( hResult, "page", NIL ) )
        RETURN .F.
    ENDIF
RETURN hResult[ "page" ][ "number" ] == nNumber .AND. hResult[ "page" ][ "size" ] == 2 .AND. ;
    hResult[ "page" ][ "hasNext" ] == lHasNext .AND. hb_HGetDef( hResult, "totalRows", NIL ) == 5 .AND. ;
    hb_HGetDef( hResult, "totalPages", NIL ) == 3

STATIC FUNCTION MCSafeFailure( hResponse, cCode )
    LOCAL hResult := hResponse[ "result" ]
RETURN hResponse[ "status" ] == 500 .AND. HB_ISHASH( hResult ) .AND. Len( hResult ) == 4 .AND. ;
    hb_HGetDef( hResult, "success", .T. ) == .F. .AND. hb_HGetDef( hResult, "code", "" ) == cCode .AND. ;
    HB_ISSTRING( hb_HGetDef( hResult, "error", NIL ) ) .AND. hb_HGetDef( hResult, "message", NIL ) == ""

STATIC FUNCTION MCListenersClosed( hHost )
    LOCAL hListener
    FOR EACH hListener IN hHost[ "listeners" ]
        IF HBBridgeServerRunning( hListener ) .OR. HBBridgeServerActive( hListener ) != 0
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

STATIC FUNCTION MCFreePort()
    LOCAL hSocket := hb_socketOpen(), nPort := 0
    IF ! Empty( hSocket )
        IF hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
            nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
        ENDIF
        hb_socketClose( hSocket )
    ENDIF
RETURN nPort

STATIC PROCEDURE MCAssert( lPassed, cLabel, hChecks )
    hChecks[ "checks" ]++
    IF ! lPassed
        hChecks[ "failures" ]++
    ENDIF
    ? iif( lPassed, "PASS: ", "FAIL: " ) + cLabel
RETURN
