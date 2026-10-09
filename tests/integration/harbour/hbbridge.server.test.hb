#include "hbsocket.ch"

#define MT_TIMEOUT_MS 3000

STATIC s_hAddonGate

// Build hbbridgeservertest.hbp or run scripts/test-hbbridge.ps1 from the project root.
PROCEDURE MTTests()

    LOCAL hServer, nFailures := 0, nChecks := 0

    MTAssert( hb_mtvm(), "Harbour MT VM enabled", @nFailures, @nChecks )
    IF ! hb_mtvm()
        ErrorLevel( 1 )
        RETURN
    ENDIF

    hServer := HBBridgeServerStart( 0, 32 )
    MTAssert( HB_ISHASH( hServer ), "server starts on an ephemeral port", @nFailures, @nChecks )
    IF HB_ISHASH( hServer )
        MTProtocolSignatures( hServer, @nFailures, @nChecks )
        MTBuiltinServices( hServer, @nFailures, @nChecks )
        MTIdleClient( hServer, @nFailures, @nChecks )
        MTParallelEcho( hServer, @nFailures, @nChecks )
        MTBadRequests( hServer, @nFailures, @nChecks )
        MTAddons( hServer, @nFailures, @nChecks )
        MTAssert( HBBridgeServerStop( hServer ), "normal server shutdown", @nFailures, @nChecks )
    ENDIF

    MTWorkerLimit( @nFailures, @nChecks )
    MTGracefulStop( @nFailures, @nChecks )

    M1ConfigTests( @nFailures, @nChecks )
    M1INIConfigTests( @nFailures, @nChecks )
    M1ServiceTests( @nFailures, @nChecks )
    M1NativeTests( @nFailures, @nChecks )
    M2FramingTests( @nFailures, @nChecks )
    M2ClockTests( @nFailures, @nChecks )
    M3SQLTests( @nFailures, @nChecks )
    HTTPTests( @nFailures, @nChecks )

    ? "MT checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )

RETURN

STATIC PROCEDURE MTProtocolSignatures( hServer, nFailures, nChecks )

    LOCAL cSignature, hResponse

    FOR EACH cSignature IN { "HBBRIDGE/1" }
        hResponse := MTRequest( hServer[ "port" ], MTEchoJson( 42 ), cSignature )
        MTAssert( MTEchoMatches( hResponse, 42 ), ;
            "Echo response preserves protocol signature " + cSignature, @nFailures, @nChecks )
        hResponse := MTRequest( hServer[ "port" ], '{"service":"Unknown","params":{}}', cSignature )
        MTAssert( MTIsError( hResponse ), ;
            "error response preserves protocol signature " + cSignature, @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE MTBuiltinServices( hServer, nFailures, nChecks )

    LOCAL hResponse

    hResponse := MTRequest( hServer[ "port" ], '{"service":"Health","params":{}}' )
    MTAssert( MTIsSuccess( hResponse ), "Health reaches Zig through the extracted C bridge", @nFailures, @nChecks )

    hResponse := MTRequest( hServer[ "port" ], '{"service":"ADDON.Execute","params":{"module":"examples/hbbridgesampleaddon.hb","params":{}}}' )
    MTAssert( MTIsSuccess( hResponse ), "sample Harbour addon compiles and executes", @nFailures, @nChecks )

RETURN

STATIC FUNCTION MTIsSuccess( hResponse )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .T.

STATIC PROCEDURE MTIdleClient( hServer, nFailures, nChecks )

    LOCAL hIdle := MTConnect( hServer[ "port" ] )
    LOCAL nStart, hResponse

    MTAssert( ! Empty( hIdle ), "idle client connects", @nFailures, @nChecks )
    IF Empty( hIdle )
        RETURN
    ENDIF
    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 1 }, 1000 ), ;
        "idle client occupies one worker", @nFailures, @nChecks )

    nStart := HBBridgeMonotonicMs()
    hResponse := MTEchoRequest( hServer[ "port" ], 1 )
    MTAssert( MTEchoMatches( hResponse, 1 ), "Echo completes while another client sends nothing", @nFailures, @nChecks )
    MTAssert( HBBridgeMonotonicMs() - nStart < 2000, ;
        "Echo does not wait for the idle client's 5s receive timeout", @nFailures, @nChecks )

    hb_socketClose( hIdle )
    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 0 }, 1000 ), ;
        "idle client disconnect releases its worker", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE MTParallelEcho( hServer, nFailures, nChecks )

    LOCAL aThreads := {}, nIndex, hResponse, hThread

    FOR nIndex := 1 TO 16
        // Arguments are copied into each new thread; do not capture the loop local.
        AAdd( aThreads, hb_threadStart( @MTEchoRequest(), hServer[ "port" ], nIndex ) )
    NEXT

    FOR nIndex := 1 TO Len( aThreads )
        hThread := aThreads[ nIndex ]
        hResponse := NIL
        IF MTJoin( hThread, @hResponse )
            MTAssert( MTEchoMatches( hResponse, nIndex ), ;
                "parallel Echo preserves payload " + hb_ntos( nIndex ), @nFailures, @nChecks )
        ELSE
            MTAssert( .F., "parallel Echo thread completes " + hb_ntos( nIndex ), @nFailures, @nChecks )
        ENDIF
    NEXT

    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 0 }, 1000 ), ;
        "parallel clients release every worker", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE MTBadRequests( hServer, nFailures, nChecks )

    LOCAL aRequests := { "{", "[]", '{"service":17,"params":{}}', ;
        '{"service":"Echo"}', '{"service":"Unknown","params":{}}' }
    LOCAL cRequest, hResponse

    FOR EACH cRequest IN aRequests
        hResponse := MTRequest( hServer[ "port" ], cRequest )
        MTAssert( MTIsError( hResponse ), "invalid request returns an error: " + cRequest, @nFailures, @nChecks )
        MTAssert( MTEchoMatches( MTEchoRequest( hServer[ "port" ], 77 ), 77 ), ;
            "server remains healthy after invalid request", @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE MTAddons( hServer, nFailures, nChecks )

    LOCAL aThreads := {}, hThread, hResponse, nIndex, nStart, nPrevious

    IF File( "addons/hbbridge_mt_fault.hrb" )
        hResponse := MTRequest( hServer[ "port" ], '{"service":"ADDON.Execute","params":{"module":"hbbridge_mt_fault.hrb","params":{}}}' )
        MTAssert( MTIsError( hResponse ), "addon runtime error is contained by its worker", @nFailures, @nChecks )
        MTAssert( MTEchoMatches( MTEchoRequest( hServer[ "port" ], 88 ), 88 ), ;
            "Echo succeeds after addon runtime error", @nFailures, @nChecks )
    ELSE
        ? "SKIP: compile tests/integration/harbour/hbbridgefaultaddon.hb to addons/hbbridge_mt_fault.hrb"
    ENDIF

    IF File( "addons/hbbridge_mt_isolation.hrb" )
        s_hAddonGate := { "mutex" => hb_mutexCreate(), "release" => hb_mutexCreate(), ;
            "participants" => {=>}, "expected" => 12 }
        nStart := HBBridgeMonotonicMs()
        FOR nIndex := 1 TO 12
            AAdd( aThreads, hb_threadStart( @MTAddonRequest(), hServer[ "port" ], nIndex ) )
        NEXT
        FOR nIndex := 1 TO Len( aThreads )
            hThread := aThreads[ nIndex ]
            hResponse := NIL
            IF MTJoin( hThread, @hResponse )
                IF ! MTAddonMatches( hResponse, nIndex )
                    ? "Addon isolation response:", hb_jsonEncode( { "expectedId" => nIndex, "response" => hResponse } )
                ENDIF
                MTAssert( MTAddonMatches( hResponse, nIndex ), ;
                    "simultaneously active addon owns its static state " + hb_ntos( nIndex ), @nFailures, @nChecks )
            ELSE
                MTAssert( .F., "addon thread completes " + hb_ntos( nIndex ), @nFailures, @nChecks )
            ENDIF
        NEXT
        MTAssert( HBBridgeMonotonicMs() - nStart < 1500, ;
            "12 addon calls overlap their 200ms waits", @nFailures, @nChecks )
        MTAssert( hb_mutexEval( s_hAddonGate[ "mutex" ], ;
            {|| Len( s_hAddonGate[ "participants" ] ) == s_hAddonGate[ "expected" ] } ), ;
            "all 12 independently loaded HRBs reached the barrier before release", @nFailures, @nChecks )
        s_hAddonGate := NIL

        // Native reload keeps the inactive module's initialized STATIC frame.
        // Per-call state must be initialized by the addon, not assumed reset.
        nPrevious := NIL
        FOR nIndex := 1 TO 3
            hResponse := MTRequest( hServer[ "port" ], hb_jsonEncode( { "service" => "ADDON.Execute", ;
                "params" => { "module" => "hbbridge_mt_isolation.hrb", "params" => { "id" => nIndex } } } ) )
            IF ! MTAddonMatches( hResponse, nIndex )
                ? "Addon sequential response:", hb_jsonEncode( { "expectedId" => nIndex, "response" => hResponse } )
            ENDIF
            MTAssert( MTAddonMatches( hResponse, nIndex ), ;
                "sequential addon initializes its own call state " + hb_ntos( nIndex ), @nFailures, @nChecks )
            IF nPrevious != NIL
                MTAssert( HB_ISHASH( hResponse ) .AND. ;
                    hb_HGetDef( hResponse, "counterBefore", NIL ) == nPrevious, ;
                    "native HRB reload preserves the previous STATIC counter " + hb_ntos( nIndex ), @nFailures, @nChecks )
            ENDIF
            IF HB_ISHASH( hResponse )
                nPrevious := hb_HGetDef( hResponse, "counter", NIL )
            ELSE
                nPrevious := NIL
            ENDIF
        NEXT
    ELSE
        ? "SKIP: compile tests/integration/harbour/hbbridgeisolationaddon.hb to addons/hbbridge_mt_isolation.hrb"
    ENDIF

RETURN

STATIC PROCEDURE MTWorkerLimit( nFailures, nChecks )

    LOCAL hServer := HBBridgeServerStart( 0, 1 )
    LOCAL hIdle, hExcess, cByte := Space( 1 ), nReceived, nError

    MTAssert( HB_ISHASH( hServer ), "single-worker server starts", @nFailures, @nChecks )
    IF ! HB_ISHASH( hServer )
        RETURN
    ENDIF

    hIdle := MTConnect( hServer[ "port" ] )
    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 1 }, 1000 ), ;
        "configured worker slot is occupied", @nFailures, @nChecks )

    hExcess := MTConnect( hServer[ "port" ] )
    IF ! Empty( hExcess )
        nReceived := hb_socketRecv( hExcess, @cByte, 1, 0, 1000 )
        nError := hb_socketGetError()
        MTAssert( nReceived == 0 .OR. ( nReceived < 0 .AND. nError != HB_SOCKET_ERR_TIMEOUT ), ;
            "excess client is promptly closed at the worker limit", @nFailures, @nChecks )
        hb_socketClose( hExcess )
    ELSE
        MTAssert( .T., "excess client cannot connect at the worker limit", @nFailures, @nChecks )
    ENDIF
    MTAssert( HBBridgeServerActive( hServer ) == 1, "worker count stays within the configured limit", @nFailures, @nChecks )

    IF ! Empty( hIdle )
        hb_socketClose( hIdle )
    ENDIF
    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 0 }, 1000 ), ;
        "worker slot becomes available after disconnect", @nFailures, @nChecks )
    MTAssert( MTEchoMatches( MTEchoRequest( hServer[ "port" ], 99 ), 99 ), ;
        "server accepts work after capacity becomes available", @nFailures, @nChecks )
    MTAssert( HBBridgeServerStop( hServer ), "single-worker server stops", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE MTGracefulStop( nFailures, nChecks )

    LOCAL hServer := HBBridgeServerStart( 0, 2 )
    LOCAL hIdle, hStop, hResponse, lStopped := .F.

    MTAssert( HB_ISHASH( hServer ), "shutdown test server starts", @nFailures, @nChecks )
    IF ! HB_ISHASH( hServer )
        RETURN
    ENDIF

    hIdle := MTConnect( hServer[ "port" ] )
    MTAssert( ! Empty( hIdle ), "in-flight shutdown client connects", @nFailures, @nChecks )
    IF Empty( hIdle )
        HBBridgeServerStop( hServer )
        RETURN
    ENDIF
    MTAssert( MTWait( {|| HBBridgeServerActive( hServer ) == 1 }, 1000 ), ;
        "shutdown starts with an admitted worker", @nFailures, @nChecks )

    hStop := hb_threadStart( @HBBridgeServerStop(), hServer )
    MTAssert( MTWait( {|| ! HBBridgeServerRunning( hServer ) }, 1000 ), ;
        "shutdown marks listener as stopped", @nFailures, @nChecks )
    MTAssert( MTWait( {|| MTConnectionRefused( hServer[ "port" ] ) }, 1000 ), ;
        "shutdown refuses new connections before draining finishes", @nFailures, @nChecks )
    MTAssert( hb_threadWait( hStop, 0 ) == 0, ;
        "shutdown waits for its in-flight worker", @nFailures, @nChecks )

    hResponse := MTExchange( hIdle, MTEchoJson( 123 ) )
    hb_socketClose( hIdle )
    MTAssert( MTEchoMatches( hResponse, 123 ), ;
        "admitted request completes during graceful shutdown", @nFailures, @nChecks )
    MTAssert( MTJoin( hStop, @lStopped ), "shutdown thread finishes after worker drains", @nFailures, @nChecks )
    MTAssert( lStopped == .T., "graceful shutdown reports success", @nFailures, @nChecks )
    MTAssert( HBBridgeServerActive( hServer ) == 0, "shutdown leaves no active workers", @nFailures, @nChecks )
    MTAssert( MTConnectionRefused( hServer[ "port" ] ), "stopped port refuses new clients", @nFailures, @nChecks )

RETURN

STATIC FUNCTION MTConnect( nPort )

    LOCAL hSocket := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_IP )

    IF ! Empty( hSocket )
        IF ! hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 1000 )
            hb_socketClose( hSocket )
            hSocket := NIL
        ENDIF
    ENDIF

RETURN hSocket

STATIC FUNCTION MTConnectionRefused( nPort )

    LOCAL hSocket := MTConnect( nPort )

    IF ! Empty( hSocket )
        hb_socketClose( hSocket )
        RETURN .F.
    ENDIF

RETURN .T.

STATIC FUNCTION MTEchoJson( nIndex )

    LOCAL hParams := { "id" => nIndex, "payload" => Replicate( hb_ntos( nIndex ) + "-", 30 ) }

RETURN hb_jsonEncode( { "service" => "Echo", "params" => hParams } )

STATIC FUNCTION MTEchoRequest( nPort, nIndex )
RETURN MTRequest( nPort, MTEchoJson( nIndex ) )

STATIC FUNCTION MTAddonRequest( nPort, nIndex )
RETURN MTRequest( nPort, hb_jsonEncode( { "service" => "ADDON.Execute", ;
    "params" => { "module" => "hbbridge_mt_isolation.hrb", ;
        "params" => { "id" => nIndex, "synchronize" => .T. } } } ) )

FUNCTION MTAddonBarrier( nIndex )

    LOCAL nArrived, nRelease, lReady := .F.

    nArrived := hb_mutexEval( s_hAddonGate[ "mutex" ], {|| MTAddonArrive( nIndex ) } )
    IF nArrived == s_hAddonGate[ "expected" ]
        FOR nRelease := 1 TO s_hAddonGate[ "expected" ]
            hb_mutexNotify( s_hAddonGate[ "release" ], .T. )
        NEXT
    ENDIF

RETURN hb_mutexSubscribe( s_hAddonGate[ "release" ], 2, @lReady ) .AND. lReady

STATIC FUNCTION MTAddonArrive( nIndex )
    s_hAddonGate[ "participants" ][ hb_ntos( nIndex ) ] := .T.
RETURN Len( s_hAddonGate[ "participants" ] )

FUNCTION MTRequest( nPort, cJson, cSignature )

    LOCAL hSocket := MTConnect( nPort ), hResponse := NIL

    IF ! Empty( hSocket )
        hResponse := MTExchange( hSocket, cJson, cSignature )
        hb_socketClose( hSocket )
    ENDIF

RETURN hResponse

STATIC FUNCTION MTExchange( hSocket, cJson, cSignature )

    LOCAL cFrame, nZipError, cCompressed
    LOCAL cResponse := "", cChunk, nReceived, nDeadline := HBBridgeMonotonicMs() + MT_TIMEOUT_MS
    LOCAL nHeaderEnd, aHeader, cBody, hResponse

    hb_default( @cSignature, "HBBRIDGE/1" )
    cFrame := cSignature + "|JSON|" + hb_ntos( hb_BLen( cJson ) ) + hb_BChar( 10 ) + cJson
    cCompressed := hb_gzCompress( cFrame, NIL, @nZipError )

    IF nZipError != 0
        RETURN NIL
    ENDIF
    // Small-request helper; deliberate fragmentation is covered by M2FramingTests.
    IF hb_socketSend( hSocket, cCompressed, hb_BLen( cCompressed ), 0, MT_TIMEOUT_MS ) != hb_BLen( cCompressed )
        RETURN NIL
    ENDIF
    DO WHILE HBBridgeMonotonicMs() < nDeadline
        cChunk := Space( 4096 )
        nReceived := hb_socketRecv( hSocket, @cChunk, hb_BLen( cChunk ), 0, ;
            Max( 1, nDeadline - HBBridgeMonotonicMs() ) )
        IF nReceived == 0
            EXIT
        ELSEIF nReceived < 0
            RETURN NIL
        ENDIF
        cResponse += hb_BLeft( cChunk, nReceived )
    ENDDO
    IF nReceived != 0 .OR. Empty( cResponse )
        RETURN NIL
    ENDIF

    cFrame := hb_ZUncompress( cResponse )
    IF ! HB_ISSTRING( cFrame )
        RETURN NIL
    ENDIF
    nHeaderEnd := hb_BAt( hb_BChar( 10 ), cFrame )
    IF nHeaderEnd <= 0
        RETURN NIL
    ENDIF
    aHeader := hb_ATokens( hb_BLeft( cFrame, nHeaderEnd - 1 ), "|" )
    IF Len( aHeader ) != 3
        RETURN NIL
    ENDIF
    cBody := hb_BSubStr( cFrame, nHeaderEnd + 1 )
    IF aHeader[ 1 ] != cSignature .OR. aHeader[ 2 ] != "JSON" .OR. Val( aHeader[ 3 ] ) != hb_BLen( cBody )
        RETURN NIL
    ENDIF
    IF hb_jsonDecode( cBody, @hResponse ) != hb_BLen( cBody )
        RETURN NIL
    ENDIF

RETURN hResponse

STATIC FUNCTION MTEchoMatches( hResponse, nIndex )

    LOCAL hParams

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" ) .OR. ! hb_HHasKey( hResponse, "params" )
        RETURN .F.
    ENDIF
    hParams := hResponse[ "params" ]
    IF ! HB_ISHASH( hParams )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hParams, "id" ) .OR. ! hb_HHasKey( hParams, "payload" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .T. .AND. hParams[ "id" ] == nIndex .AND. ;
    hParams[ "payload" ] == Replicate( hb_ntos( nIndex ) + "-", 30 )

STATIC FUNCTION MTAddonMatches( hResponse, nIndex )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "id" ) .OR. ! hb_HHasKey( hResponse, "counter" ) .OR. ;
        ! hb_HHasKey( hResponse, "counterBefore" ) .OR. ! hb_HHasKey( hResponse, "owner" ) .OR. ;
        ! hb_HHasKey( hResponse, "allActive" )
        RETURN .F.
    ENDIF

RETURN hb_HGetDef( hResponse, "success", .F. ) == .T. .AND. ;
    hResponse[ "id" ] == nIndex .AND. hResponse[ "owner" ] == nIndex .AND. ;
    hResponse[ "allActive" ] == .T. .AND. HB_ISNUMERIC( hResponse[ "counterBefore" ] ) .AND. ;
    hResponse[ "counter" ] == hResponse[ "counterBefore" ] + 1

STATIC FUNCTION MTIsError( hResponse )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .F.

STATIC FUNCTION MTJoin( hThread, xResult )

    IF Empty( hThread )
        RETURN .F.
    ENDIF
    IF hb_threadWait( hThread, 7 ) == 0
        hb_threadQuitRequest( hThread )
        hb_threadDetach( hThread )
        RETURN .F.
    ENDIF

RETURN hb_threadJoin( hThread, @xResult )

STATIC FUNCTION MTWait( bCondition, nTimeout )

    LOCAL nDeadline := HBBridgeMonotonicMs() + nTimeout

    DO WHILE HBBridgeMonotonicMs() < nDeadline
        IF Eval( bCondition )
            RETURN .T.
        ENDIF
        hb_idleSleep( 0.01 )
    ENDDO

RETURN Eval( bCondition )

STATIC PROCEDURE MTAssert( lCondition, cMessage, nFailures, nChecks )

    nChecks++
    IF lCondition
        ? "PASS:", cMessage
    ELSE
        nFailures++
        ? "FAIL:", cMessage
    ENDIF

RETURN
