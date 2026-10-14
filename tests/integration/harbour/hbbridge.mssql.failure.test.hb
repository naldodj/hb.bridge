/* Released to Public Domain. */
#include "dbinfo.ch"
#include "hbsocket.ch"

REQUEST HB_CODEPAGE_UTF8EX

/* Explicit opt-in MSSQL fixtures: constants and bounded WAITFOR only.
 * No ERP tables, server shutdown, credentials or dictionary changes.
 */
PROCEDURE MSSQLFailureTests( cConfigPath, cProfile, cFailureDriver, cMode )

    LOCAL nFailures := 0, nChecks := 0, nExit := 1
    LOCAL cPreviousCodepage := hb_cdpSelect()

    IF ! HB_ISSTRING( cConfigPath ) .OR. ! HB_ISSTRING( cProfile ) .OR. ;
        ! HB_ISSTRING( cFailureDriver )
        ? "MSSQL failure prerequisite: CONFIG_PROFILE_AND_DRIVER_REQUIRED"
        ErrorLevel( 2 )
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        nExit := MFRun( cConfigPath, cProfile, cFailureDriver, cMode, @nFailures, @nChecks )
    RECOVER
        ? "MSSQL failure acceptance: UNEXPECTED_RUNTIME_ERROR"
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE
    ErrorLevel( nExit )

RETURN

STATIC FUNCTION MFRun( cConfigPath, cProfile, cFailureDriver, cMode, nFailures, nChecks )

    LOCAL hPrivate, hConfig, hProfiles, hWorking, hRegistry, hHost := NIL, cError
    LOCAL hRefused := NIL, nRefusedPort, pNative := NIL, hResult, hCases, hCase, cRoute
    LOCAL nStarted, nElapsed, nControlElapsed := 0, nTransport, hResponse, nKey
    LOCAL hRecovery, cAuth := "Bearer m06-http-test-only", hPorts, hAddress
    LOCAL hRoutes := { 1 => "local", 2 => "NETIO", 3 => "TCP", 4 => "HTTP" }, lReady := .F.
    LOCAL cWaitSQL := "WAITFOR DELAY '00:00:04'; SELECT 77 AS RECOVERY_ID"

    hPrivate := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
    IF hPrivate == NIL .OR. Empty( AllTrim( cFailureDriver ) )
        ? "MSSQL failure prerequisite: CONFIG_OR_DRIVER_INVALID"
        RETURN 2
    ENDIF
    IF ! hb_HHasKey( hPrivate[ "sqlProfiles" ], cProfile ) .OR. ;
        cProfile == "m06/refused" .OR. cProfile == "m06/query-timeout"
        ? "MSSQL failure prerequisite: PROFILE_INVALID"
        RETURN 2
    ENDIF
    hWorking := hb_HClone( hPrivate[ "sqlProfiles" ][ cProfile ] )
    IF hWorking[ "driver" ] != "mssql"
        ? "MSSQL failure prerequisite: MSSQL_PROFILE_REQUIRED"
        RETURN 2
    ENDIF
    hWorking[ "loginTimeoutSeconds" ] := 2
    hWorking[ "queryTimeoutSeconds" ] := 5
    hRefused := hb_socketOpen()
    IF Empty( hRefused ) .OR. ! hb_socketBind( hRefused, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
        IF ! Empty( hRefused )
            hb_socketClose( hRefused )
        ENDIF
        ? "MSSQL failure prerequisite: REFUSED_PORT_UNAVAILABLE"
        RETURN 2
    ENDIF
    /* Keep the port bound WITHOUT listen, so another process cannot reuse it. */
    hAddress := hb_socketGetSockName( hRefused )
    nRefusedPort := hAddress[ HB_SOCKET_ADINFO_PORT ]
    BEGIN SEQUENCE WITH __BreakBlock()
        hProfiles := { cProfile => hWorking, ;
            "m06/refused" => { "driver" => "mssql", "odbcDriver" => cFailureDriver, ;
                "server" => "tcp:127.0.0.1," + hb_ntos( nRefusedPort ), "database" => "master", ;
                "authentication" => "sql", "username" => "m06-fictitious-user", ;
                "password" => "m06-fictitious-secret", "encrypt" => "optional", ;
                "loginTimeoutSeconds" => 1, "queryTimeoutSeconds" => 1 }, ;
            "m06/query-timeout" => hb_HClone( hWorking ) }
        hProfiles[ "m06/query-timeout" ][ "queryTimeoutSeconds" ] := 1
        hProfiles := HBBridgeSQLProfiles( hProfiles, hb_cwd(), @cError )
        IF hProfiles == NIL
            ? "MSSQL failure prerequisite: TEST_PROFILE_INVALID"
            Break( NIL )
        ENDIF
        hRegistry := HBBridgeBuiltinRegistry( hProfiles )
        hRecovery := { "alias" => cProfile, "sql" => "SELECT 77 AS RECOVERY_ID" }
        hResult := MFQuery( hRegistry, hRecovery )
        IF ! MFRecovered( hResult )
            ? "MSSQL failure prerequisite: WORKING_CONNECTION_FAILED"
            Break( NIL )
        ENDIF
        MFAssert( .T., "real MSSQL constant baseline", @nFailures, @nChecks )
        MFExecuteTimeout( hWorking, @nControlElapsed, @nFailures, @nChecks )

        hConfig := HBBridgeConfig( {} )
        hConfig[ "protheusHost" ] := "127.0.0.1"
        hConfig[ "protheusPort" ] := 0
        hConfig[ "netioHost" ] := "127.0.0.1"
        hConfig[ "netioPort" ] := MFFreePort()
        hConfig[ "netioPassword" ] := "m06-netio-test-only"
        hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "m06-netio", hb_cwd() )
        hConfig[ "httpEnabled" ] := .T.
        hConfig[ "httpHost" ] := "127.0.0.1"
        hConfig[ "httpPort" ] := MFFreePort()
        hConfig[ "httpPassword" ] := "m06-http-test-only"
        hConfig[ "sqlProfiles" ] := hProfiles
        hHost := HBBridgeHostStart( hConfig, @cError )
        IF hHost == NIL
            ? "MSSQL failure prerequisite: ISOLATED_HOST_FAILED"
            Break( NIL )
        ENDIF
        pNative := netio_GetConnection( "127.0.0.1", hConfig[ "netioPort" ], 7000, hConfig[ "netioPassword" ] )
        IF Empty( pNative )
            ? "MSSQL failure prerequisite: NATIVE_CLIENT_FAILED"
            Break( NIL )
        ENDIF
        hPorts := { "tcp" => hHost[ "listeners" ][ "protheus" ][ "port" ], ;
            "http" => hConfig[ "httpPort" ] }
        hCases := { "invalidSQL" => { "params" => { "alias" => cProfile, "sql" => "SELECT FROM" }, ;
                "code" => "QUERY_FAILED", "error" => "Could not open or read the SQL query result." }, ;
            "unknownProfile" => { "params" => { "alias" => "__HBBridgeM06UnknownProfile__", "sql" => "SELECT 1" }, ;
                "code" => "PROFILE_NOT_FOUND", "error" => "Connection profile is not configured." }, ;
            "refusedConnection" => { "params" => { "alias" => "m06/refused", "sql" => "SELECT 1" }, ;
                "code" => "CONNECTION_FAILED", "error" => "Database connection is unavailable." }, ;
            "queryTimeout" => { "params" => { "alias" => "m06/query-timeout", "sql" => cWaitSQL }, ;
                "code" => "QUERY_FAILED", "error" => "Could not open or read the SQL query result." } }
        FOR nTransport := 1 TO 4
            cRoute := hRoutes[ nTransport ]
            FOR EACH hCase IN hCases
                nStarted := HBBridgeMonotonicMs()
                hResponse := MFCall( nTransport, hRegistry, pNative, hPorts, cAuth, hCase[ "params" ] )
                nElapsed := HBBridgeMonotonicMs() - nStarted
                MFAssert( MFSafeFailure( hResponse[ "result" ], hCase ), ;
                    cRoute + " safe error: " + hCase:__enumKey(), @nFailures, @nChecks )
                IF nTransport == 4
                    MFAssert( hResponse[ "status" ] == 500, ;
                        cRoute + " error status: " + hCase:__enumKey(), @nFailures, @nChecks )
                ENDIF
                IF hCase:__enumKey() == "queryTimeout"
                    MFAssert( nElapsed >= 500 .AND. nElapsed < nControlElapsed, ;
                        cRoute + " native query timeout precedes the unbounded control", @nFailures, @nChecks )
                ENDIF
                hResponse := MFCall( nTransport, hRegistry, pNative, hPorts, cAuth, hRecovery )
                MFAssert( MFRecovered( hResponse[ "result" ] ), ;
                    cRoute + " recovery: " + hCase:__enumKey(), @nFailures, @nChecks )
            NEXT
        NEXT
        lReady := .T.
        ? "MSSQL controlled failure checks:", nChecks, "failures:", nFailures, "skips: 0"
        IF cMode == "serve" .AND. nFailures == 0
            ? 'TCP test: U_HBBridgeFailureTest("' + cProfile + '","m06/refused","127.0.0.1",' + ;
                hb_ntos( hPorts[ "tcp" ] ) + ',7000,"m06/query-timeout")'
            ? 'HTTP test: U_HBBridgeHTTPFailureTest("' + cProfile + '","m06/refused","http://127.0.0.1:' + ;
                hb_ntos( hPorts[ "http" ] ) + '","m06-http-test-only",7,"m06/query-timeout")'
            ? "Isolated validation host ready for 600 seconds; Esc/Ctrl+Q stops it."
            nStarted := HBBridgeMonotonicMs()
            DO WHILE HBBridgeMonotonicMs() - nStarted < 600000 .AND. HBBridgeHostRunning( hHost )
                nKey := Inkey( 0.1 )
                IF nKey == 27 .OR. nKey == 17
                    EXIT
                ENDIF
            ENDDO
        ENDIF
    ALWAYS
        IF pNative != NIL
            pNative := NIL
            netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] )
        ENDIF
        IF hHost != NIL
            HBBridgeHostStop( hHost )
        ENDIF
        hb_socketClose( hRefused )
    END SEQUENCE

RETURN iif( ! lReady, 2, iif( nFailures == 0, 0, 1 ) )

STATIC PROCEDURE MFExecuteTimeout( hProfile, nControlElapsed, nFailures, nChecks )

    LOCAL nPrevious := rddInfo( RDDI_CONNECTION, NIL, "SQLMIX" ), nConnection := 0
    LOCAL nSeconds, nStarted, nElapsed, lExecuted, cNativeError

    /* The RDD requires a positional array. No native error text is printed. */
    FOR nSeconds := 0 TO 1
        BEGIN SEQUENCE WITH __BreakBlock()
            nConnection := rddInfo( RDDI_CONNECT, { "ODBC", hProfile[ "connectionString" ], 2, nSeconds }, "SQLMIX" )
            MFAssert( nConnection > 0, "native execution timeout fixture connects", @nFailures, @nChecks )
            IF nConnection > 0
                nStarted := HBBridgeMonotonicMs()
                lExecuted := rddInfo( RDDI_EXECUTE, "WAITFOR DELAY '00:00:04'", "SQLMIX", nConnection )
                nElapsed := HBBridgeMonotonicMs() - nStarted
                IF nSeconds == 0
                    nControlElapsed := nElapsed
                    MFAssert( lExecuted .AND. nElapsed >= 3500, ;
                        "explicit zero allows the bounded four-second control", @nFailures, @nChecks )
                ELSE
                    cNativeError := rddInfo( RDDI_ERROR, NIL, "SQLMIX" )
                    MFAssert( ! lExecuted .AND. HB_ISSTRING( cNativeError ) .AND. "HYT00" $ cNativeError, ;
                        "native driver reports SQL execution timeout", @nFailures, @nChecks )
                    MFAssert( nElapsed >= 500 .AND. nElapsed < nControlElapsed, ;
                        "one-second native execution timeout precedes the control", @nFailures, @nChecks )
                ENDIF
            ENDIF
        ALWAYS
            IF nConnection > 0
                rddInfo( RDDI_DISCONNECT, NIL, "SQLMIX", nConnection )
                nConnection := 0
            ENDIF
            rddInfo( RDDI_CONNECTION, nPrevious, "SQLMIX" )
        END SEQUENCE
    NEXT

RETURN

STATIC FUNCTION MFCall( nTransport, hRegistry, pNative, hPorts, cAuth, hParams )
    LOCAL hResult, hHTTP
    DO CASE
    CASE nTransport == 1
        hResult := MFQuery( hRegistry, hParams )
    CASE nTransport == 2
        hResult := netio_FuncExec( pNative, "HBBridge.Call", "RPCRDD.Query", hParams )
    CASE nTransport == 3
        hResult := MFTCP( hPorts[ "tcp" ], hParams )
    OTHERWISE
        hHTTP := HBBridgeHTTPTestRequest( hPorts[ "http" ], "POST", "/api/v1/rpc", ;
            hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } ), cAuth )
        RETURN { "result" => hHTTP[ "json" ], "status" => hHTTP[ "status" ] }
    ENDCASE
RETURN { "result" => hResult, "status" => 0 }

STATIC FUNCTION MFQuery( hRegistry, hParams )
RETURN HBBridgeDispatch( hRegistry, "RPCRDD.Query", hParams, HBBridgeContext( "m06" ) )

STATIC FUNCTION MFTCP( nPort, hParams )
    LOCAL hSocket := hb_socketOpen(), cReply, hResult := NIL
    LOCAL hPolicy := { "protheusTimeoutMs" => 7000 }
    BEGIN SEQUENCE WITH __BreakBlock()
        IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 7000 ) .AND. ;
            SendResponse( hSocket, hb_jsonEncode( { "service" => "RPCRDD.Query", "params" => hParams } ), hPolicy ) .AND. ;
            ReceiveRequest( hSocket, @cReply, hPolicy )
            hb_jsonDecode( cReply, @hResult )
        ENDIF
    ALWAYS
        hb_socketClose( hSocket )
    END SEQUENCE
RETURN hResult

STATIC FUNCTION MFSafeFailure( hResult, hCase )
    IF ! HB_ISHASH( hResult )
        RETURN .F.
    ENDIF
RETURN Len( hResult ) == 4 .AND. hb_HGetDef( hResult, "success", .T. ) == .F. .AND. ;
    hb_HGetDef( hResult, "code", "" ) == hCase[ "code" ] .AND. ;
    hb_HGetDef( hResult, "error", "" ) == hCase[ "error" ] .AND. ;
    hb_HGetDef( hResult, "message", NIL ) == ""

STATIC FUNCTION MFRecovered( hResult )
    IF ! HB_ISHASH( hResult ) .OR. hb_HGetDef( hResult, "success", .F. ) != .T.
        RETURN .F.
    ENDIF
    IF ! HB_ISHASH( hb_HGetDef( hResult, "rows", NIL ) )
        RETURN .F.
    ENDIF
    IF ! HB_ISHASH( hb_HGetDef( hResult[ "rows" ], "1", NIL ) )
        RETURN .F.
    ENDIF
RETURN hb_HGetDef( hResult, "rowCount", 0 ) == 1 .AND. ;
    hb_HGetDef( hResult[ "rows" ][ "1" ], "RECOVERY_ID", NIL ) == 77

STATIC FUNCTION MFFreePort()
    LOCAL hSocket := hb_socketOpen(), nPort := 0
    IF ! Empty( hSocket )
        IF hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
            nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
        ENDIF
        hb_socketClose( hSocket )
    ENDIF
RETURN nPort

STATIC PROCEDURE MFAssert( lPassed, cLabel, nFailures, nChecks )
    nChecks++
    IF ! lPassed
        nFailures++
    ENDIF
    ? iif( lPassed, "PASS: ", "FAIL: " ) + cLabel
RETURN
