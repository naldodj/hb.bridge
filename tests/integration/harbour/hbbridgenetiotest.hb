#include "hbsocket.ch"
#include "fileio.ch"

PROCEDURE M1NativeTests( nFailures, nChecks )

    LOCAL hConfig := HBBridgeConfig( {} ), hHost := NIL, cError, pData := NIL, pAdmin := NIL
    LOCAL hResult, hJson, aNative, cBinary := Chr( 0 ) + Chr( 255 ) + "Harbour", cBlock, xDecoded
    LOCAL pFile := NIL, cRead, nStart, nRetry, hBusy, nBusyPort, hFailed, cAdminFile, hError
    LOCAL aThreads := {}, nIndex, hThread

    hConfig[ "protheusHost" ] := "127.0.0.1"
    hConfig[ "protheusPort" ] := 0
    hConfig[ "netioHost" ] := "127.0.0.1"
    hConfig[ "netioPassword" ] := "native-test-only"
    hConfig[ "adminPassword" ] := "admin-test-only"
    hConfig[ "netioRoot" ] := HBBridgeAbsolutePath( "netio-data", hb_cwd() )
    hConfig[ "netioTimeout" ] := 2000
    FOR nRetry := 1 TO 5
        hConfig[ "netioPort" ] := M1FreePort()
        hConfig[ "adminPort" ] := M1FreePort()
        hHost := HBBridgeHostStart( hConfig, @cError )
        IF hHost != NIL
            EXIT
        ENDIF
    NEXT
    M1Assert( hHost != NIL, "shared host starts three endpoints: " + cError, @nFailures, @nChecks )
    IF hHost == NIL
        RETURN
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        pData := netio_GetConnection( "127.0.0.1", hConfig[ "netioPort" ], 2000, hConfig[ "netioPassword" ] )
        M1Assert( ! Empty( pData ), "native client connects with NETIO credential", @nFailures, @nChecks )
        IF Empty( pData )
            Break( "NETIO connection failed" )
        ENDIF
        M1Assert( netio_ProcExists( pData, "HBBridge.Call" ) .AND. ! netio_ProcExists( pData, "FERASE" ), ;
            "RPC filter exposes only explicit gateway", @nFailures, @nChecks )
        aNative := { NIL, .T., 123.45, SToD( "20261001" ), hb_SToT( "20261001123456789" ), ;
            cBinary, { "nested" => { 1, "two" } } }
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Echo", aNative )
        M1Assert( hResult[ "success" ] .AND. hb_Serialize( hResult[ "params" ] ) == hb_Serialize( aNative ), ;
            "NETIO preserves native date, timestamp, binary, null and nested values", @nFailures, @nChecks )
        cBlock := hb_Serialize( aNative )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Echo", cBlock )
        xDecoded := hb_Deserialize( hResult[ "params" ] )
        M1Assert( hb_Serialize( xDecoded ) == hb_Serialize( aNative ), ;
            "explicit serialized block roundtrip", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Health", {=>} )
        hJson := MTRequest( hHost[ "listeners" ][ "protheus" ][ "port" ], '{"service":"Health","params":{}}' )
        M1Assert( hResult[ "success" ] .AND. hResult[ "message" ] == hJson[ "message" ], ;
            "same Health result through native and Protheus adapters", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Core.Upper", "xbase" )
        M1Assert( hResult[ "result" ] == "XBASE", "native client invokes Harbour core", @nFailures, @nChecks )
        FOR nIndex := 1 TO 12
            AAdd( aThreads, hb_threadStart( 0, @M1NativeEcho(), pData, nIndex ) )
        NEXT
        FOR nIndex := 1 TO Len( aThreads )
            hThread := aThreads[ nIndex ]
            hResult := NIL
            hb_threadJoin( hThread, @hResult )
            M1Assert( HB_ISHASH( hResult ) .AND. hResult[ "success" ] .AND. ;
                hResult[ "params" ][ "index" ] == nIndex, ;
                "parallel native calls preserve arguments " + hb_ntos( nIndex ), @nFailures, @nChecks )
        NEXT
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Service.List" )
        M1Assert( Len( hResult[ "services" ] ) == 6, "native service discovery", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "ADDON.Execute", ;
            { "module" => "examples/hbbridgesampleaddon.hb", "params" => {=>} } )
        M1Assert( hResult[ "success" ], "native client executes existing JSON ABI addon", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "ADDON.Execute", ;
            { "module" => "hbbridge_mt_fault.hrb", "params" => {=>} } )
        M1Assert( hResult[ "code" ] == "SERVICE_ERROR", "NETIO contains addon failure", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Echo", "after fault" )
        M1Assert( hResult[ "params" ] == "after fault", "NETIO connection survives addon failure", @nFailures, @nChecks )
        hResult := netio_FuncExec( pData, "HBBridge.Call", "Admin.Status" )
        M1Assert( hResult[ "code" ] == "FORBIDDEN", "NETIO data cannot administer host", @nFailures, @nChecks )
        M1Assert( netio_Connect( "127.0.0.1", hConfig[ "netioPort" ], 2000, hConfig[ "netioPassword" ] ), ;
            "register native VF IO provider", @nFailures, @nChecks )
        pFile := hb_vfOpen( "net:binary.dat", FO_CREAT + FO_TRUNC + FO_READWRITE + FO_EXCLUSIVE )
        M1Assert( ! Empty( pFile ), "VF IO opens remote file", @nFailures, @nChecks )
        IF ! Empty( pFile )
            M1Assert( hb_vfWrite( pFile, cBinary ) == Len( cBinary ), "VF IO writes binary bytes", @nFailures, @nChecks )
            hb_vfSeek( pFile, 0, FS_SET )
            cRead := Space( Len( cBinary ) )
            M1Assert( hb_vfRead( pFile, @cRead, Len( cRead ) ) == Len( cBinary ) .AND. cRead == cBinary, ;
                "VF IO reads identical binary bytes", @nFailures, @nChecks )
            hb_vfClose( pFile )
            pFile := NIL
        ENDIF
        netio_Disconnect( "127.0.0.1", hConfig[ "netioPort" ] )
        M1Assert( M1CredentialRejected( hConfig[ "adminPort" ] ), ;
            "admin rejects incorrect native credential", @nFailures, @nChecks )
        pAdmin := netio_GetConnection( "127.0.0.1", hConfig[ "adminPort" ], 2000, hConfig[ "adminPassword" ] )
        M1Assert( ! Empty( pAdmin ), "admin connects with separate credential", @nFailures, @nChecks )
        hResult := netio_FuncExec( pAdmin, "HBBridge.Admin.Status" )
        M1Assert( Len( hResult[ "endpoints" ] ) == 3 .AND. ! ( "Password" $ hb_jsonEncode( hResult ) ), ;
            "admin reports endpoint status without secrets", @nFailures, @nChecks )
        hResult := netio_FuncExec( pAdmin, "HBBridge.Call", "Echo", "denied" )
        M1Assert( hResult[ "code" ] == "FORBIDDEN", "admin context cannot execute data services", @nFailures, @nChecks )
        cAdminFile := "net:127.0.0.1:" + hb_ntos( hConfig[ "adminPort" ] ) + ":forbidden.dat"
        pFile := hb_vfOpen( cAdminFile, FO_CREAT + FO_TRUNC + FO_READWRITE + FO_EXCLUSIVE )
        M1Assert( Empty( pFile ), "admin endpoint does not expose a file root", @nFailures, @nChecks )
        nStart := HBBridgeMonotonicMs()
        M1Assert( HBBridgeHostStop( hHost ), "coordinated stop with native clients still connected", @nFailures, @nChecks )
        M1Assert( HBBridgeMonotonicMs() - nStart < 5000 .AND. ! HBBridgeHostRunning( hHost ), ;
            "stop joins idle native workers", @nFailures, @nChecks )
    RECOVER USING hError
        M1Assert( .F., "native test exception: " + hb_ValToExp( hError ), @nFailures, @nChecks )
    ALWAYS
        IF ! Empty( pFile )
            hb_vfClose( pFile )
        ENDIF
        pData := NIL
        pAdmin := NIL
        HBBridgeHostStop( hHost )
        hb_gcAll( .T. )
    END SEQUENCE
    hHost := HBBridgeHostStart( hConfig, @cError )
    M1Assert( hHost != NIL, "same native/admin ports can restart after stop", @nFailures, @nChecks )
    IF hHost != NIL
        HBBridgeHostStop( hHost )
    ENDIF
    hBusy := hb_socketOpen()
    hb_socketBind( hBusy, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    hb_socketListen( hBusy )
    nBusyPort := hb_socketGetSockName( hBusy )[ HB_SOCKET_ADINFO_PORT ]
    hConfig[ "protheusPort" ] := nBusyPort
    hFailed := HBBridgeHostStart( hConfig, @cError )
    M1Assert( hFailed == NIL .AND. ! Empty( cError ), "busy endpoint fails host startup", @nFailures, @nChecks )
    IF hFailed != NIL
        HBBridgeHostStop( hFailed )
    ENDIF
    hb_socketClose( hBusy )
    hConfig[ "protheusPort" ] := 0
    hConfig[ "adminPassword" ] := ""
    hHost := HBBridgeHostStart( hConfig, @cError )
    M1Assert( hHost != NIL, "startup rollback releases prior native listeners", @nFailures, @nChecks )
    IF hHost != NIL
        M1Assert( ! hb_HHasKey( HBBridgeHostStatus( hHost )[ "endpoints" ], "admin" ), ;
            "no admin listener without configured password", @nFailures, @nChecks )
        HBBridgeHostStop( hHost )
    ENDIF
RETURN

STATIC FUNCTION M1NativeEcho( pConnection, nIndex )
    LOCAL hResult
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Echo", { "index" => nIndex } )
    RECOVER
        hResult := HBBridgeError( "TEST_RPC_ERROR", "Native test call failed" )
    END SEQUENCE
RETURN hResult

STATIC FUNCTION M1CredentialRejected( nPort )
    LOCAL pConnection := NIL, lRejected
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        pConnection := netio_GetConnection( "127.0.0.1", nPort, 400, "incorrect-test-password" )
        lRejected := Empty( pConnection )
    RECOVER
        lRejected := .T.
    END SEQUENCE
    pConnection := NIL
    hb_gcAll( .T. )
RETURN lRejected

FUNCTION M1FreePort()
    LOCAL hSocket := hb_socketOpen(), nPort
    hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
    hb_socketClose( hSocket )
RETURN nPort

PROCEDURE M1Assert( lOK, cMessage, nFailures, nChecks )
    nChecks++
    IF lOK
        ? "PASS:", cMessage
    ELSE
        nFailures++
        ? "FAIL:", cMessage
    ENDIF
RETURN
