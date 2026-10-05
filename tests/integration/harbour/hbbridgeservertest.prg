#include "hbsocket.ch"

#define MT_TIMEOUT_MS 3000

// Build hbbridgeservertest.hbp or run scripts/test-hbbridge.ps1 from the project root.
PROCEDURE mttests()

    LOCAL hServer, nFailures := 0, nChecks := 0

    mtassert( hb_mtvm(), "Harbour MT VM enabled", @nFailures, @nChecks )
    IF ! hb_mtvm()
        ErrorLevel( 1 )
        RETURN
    ENDIF

    hServer := hbbridgeserverstart( 0, 32 )
    mtassert( HB_ISHASH( hServer ), "server starts on an ephemeral port", @nFailures, @nChecks )
    IF HB_ISHASH( hServer )
        mtprotocolsignatures( hServer, @nFailures, @nChecks )
        mtbuiltinservices( hServer, @nFailures, @nChecks )
        mtidleclient( hServer, @nFailures, @nChecks )
        mtparallelecho( hServer, @nFailures, @nChecks )
        mtbadrequests( hServer, @nFailures, @nChecks )
        mtaddons( hServer, @nFailures, @nChecks )
        mtassert( hbbridgeserverstop( hServer ), "normal server shutdown", @nFailures, @nChecks )
    ENDIF

    mtworkerlimit( @nFailures, @nChecks )
    mtgracefulstop( @nFailures, @nChecks )

    m1configtests( @nFailures, @nChecks )
    m1iniconfigtests( @nFailures, @nChecks )
    m1servicetests( @nFailures, @nChecks )
    m1nativetests( @nFailures, @nChecks )
    m2framingtests( @nFailures, @nChecks )
    m2clocktests( @nFailures, @nChecks )
    m3sqltests( @nFailures, @nChecks )

    ? "MT checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )

RETURN

STATIC PROCEDURE mtprotocolsignatures( hServer, nFailures, nChecks )

    LOCAL cSignature, hResponse

    FOR EACH cSignature IN { "HBBRIDGE/1" }
        hResponse := mtrequest( hServer[ "port" ], mtechojson( 42 ), cSignature )
        mtassert( mtechomatches( hResponse, 42 ), ;
            "Echo response preserves protocol signature " + cSignature, @nFailures, @nChecks )
        hResponse := mtrequest( hServer[ "port" ], '{"service":"Unknown","params":{}}', cSignature )
        mtassert( mtiserror( hResponse ), ;
            "error response preserves protocol signature " + cSignature, @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE mtbuiltinservices( hServer, nFailures, nChecks )

    LOCAL hResponse

    hResponse := mtrequest( hServer[ "port" ], '{"service":"Health","params":{}}' )
    mtassert( mtissuccess( hResponse ), "Health reaches Zig through the extracted C bridge", @nFailures, @nChecks )

    hResponse := mtrequest( hServer[ "port" ], '{"service":"ADDON.Execute","params":{"module":"examples/hbbridgesampleaddon.prg","params":{}}}' )
    mtassert( mtissuccess( hResponse ), "sample PRG addon compiles and executes", @nFailures, @nChecks )

RETURN

STATIC FUNCTION mtissuccess( hResponse )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .T.

STATIC PROCEDURE mtidleclient( hServer, nFailures, nChecks )

    LOCAL hIdle := mtconnect( hServer[ "port" ] )
    LOCAL nStart, hResponse

    mtassert( ! Empty( hIdle ), "idle client connects", @nFailures, @nChecks )
    IF Empty( hIdle )
        RETURN
    ENDIF
    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 1 }, 1000 ), ;
        "idle client occupies one worker", @nFailures, @nChecks )

    nStart := hbbridgemonotonicms()
    hResponse := mtechorequest( hServer[ "port" ], 1 )
    mtassert( mtechomatches( hResponse, 1 ), "Echo completes while another client sends nothing", @nFailures, @nChecks )
    mtassert( hbbridgemonotonicms() - nStart < 2000, ;
        "Echo does not wait for the idle client's 5s receive timeout", @nFailures, @nChecks )

    hb_socketClose( hIdle )
    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 0 }, 1000 ), ;
        "idle client disconnect releases its worker", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE mtparallelecho( hServer, nFailures, nChecks )

    LOCAL aThreads := {}, nIndex, hResponse, hThread

    FOR nIndex := 1 TO 16
        // Arguments are copied into each new thread; do not capture the loop local.
        AAdd( aThreads, hb_threadStart( @mtechorequest(), hServer[ "port" ], nIndex ) )
    NEXT

    FOR nIndex := 1 TO Len( aThreads )
        hThread := aThreads[ nIndex ]
        hResponse := NIL
        IF mtjoin( hThread, @hResponse )
            mtassert( mtechomatches( hResponse, nIndex ), ;
                "parallel Echo preserves payload " + hb_ntos( nIndex ), @nFailures, @nChecks )
        ELSE
            mtassert( .F., "parallel Echo thread completes " + hb_ntos( nIndex ), @nFailures, @nChecks )
        ENDIF
    NEXT

    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 0 }, 1000 ), ;
        "parallel clients release every worker", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE mtbadrequests( hServer, nFailures, nChecks )

    LOCAL aRequests := { "{", "[]", '{"service":17,"params":{}}', ;
        '{"service":"Echo"}', '{"service":"Unknown","params":{}}' }
    LOCAL cRequest, hResponse

    FOR EACH cRequest IN aRequests
        hResponse := mtrequest( hServer[ "port" ], cRequest )
        mtassert( mtiserror( hResponse ), "invalid request returns an error: " + cRequest, @nFailures, @nChecks )
        mtassert( mtechomatches( mtechorequest( hServer[ "port" ], 77 ), 77 ), ;
            "server remains healthy after invalid request", @nFailures, @nChecks )
    NEXT

RETURN

STATIC PROCEDURE mtaddons( hServer, nFailures, nChecks )

    LOCAL aThreads := {}, hThread, hResponse, nIndex, nStart

    IF File( "addons/hbbridge_mt_fault.hrb" )
        hResponse := mtrequest( hServer[ "port" ], '{"service":"ADDON.Execute","params":{"module":"hbbridge_mt_fault.hrb","params":{}}}' )
        mtassert( mtiserror( hResponse ), "addon runtime error is contained by its worker", @nFailures, @nChecks )
        mtassert( mtechomatches( mtechorequest( hServer[ "port" ], 88 ), 88 ), ;
            "Echo succeeds after addon runtime error", @nFailures, @nChecks )
    ELSE
        ? "SKIP: compile tests/integration/harbour/hbbridgefaultaddon.prg to addons/hbbridge_mt_fault.hrb"
    ENDIF

    IF File( "addons/hbbridge_mt_isolation.hrb" )
        nStart := hbbridgemonotonicms()
        FOR nIndex := 1 TO 12
            AAdd( aThreads, hb_threadStart( @mtaddonrequest(), hServer[ "port" ], nIndex ) )
        NEXT
        FOR nIndex := 1 TO Len( aThreads )
            hThread := aThreads[ nIndex ]
            hResponse := NIL
            IF mtjoin( hThread, @hResponse )
                mtassert( mtaddonmatches( hResponse, nIndex ), ;
                    "concurrent addon has private static state " + hb_ntos( nIndex ), @nFailures, @nChecks )
            ELSE
                mtassert( .F., "addon thread completes " + hb_ntos( nIndex ), @nFailures, @nChecks )
            ENDIF
        NEXT
        mtassert( hbbridgemonotonicms() - nStart < 1500, ;
            "12 addon calls overlap their 200ms waits", @nFailures, @nChecks )
    ELSE
        ? "SKIP: compile tests/integration/harbour/hbbridgeisolationaddon.prg to addons/hbbridge_mt_isolation.hrb"
    ENDIF

RETURN

STATIC PROCEDURE mtworkerlimit( nFailures, nChecks )

    LOCAL hServer := hbbridgeserverstart( 0, 1 )
    LOCAL hIdle, hExcess, cByte := Space( 1 ), nReceived, nError

    mtassert( HB_ISHASH( hServer ), "single-worker server starts", @nFailures, @nChecks )
    IF ! HB_ISHASH( hServer )
        RETURN
    ENDIF

    hIdle := mtconnect( hServer[ "port" ] )
    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 1 }, 1000 ), ;
        "configured worker slot is occupied", @nFailures, @nChecks )

    hExcess := mtconnect( hServer[ "port" ] )
    IF ! Empty( hExcess )
        nReceived := hb_socketRecv( hExcess, @cByte, 1, 0, 1000 )
        nError := hb_socketGetError()
        mtassert( nReceived == 0 .OR. ( nReceived < 0 .AND. nError != HB_SOCKET_ERR_TIMEOUT ), ;
            "excess client is promptly closed at the worker limit", @nFailures, @nChecks )
        hb_socketClose( hExcess )
    ELSE
        mtassert( .T., "excess client cannot connect at the worker limit", @nFailures, @nChecks )
    ENDIF
    mtassert( hbbridgeserveractive( hServer ) == 1, "worker count stays within the configured limit", @nFailures, @nChecks )

    IF ! Empty( hIdle )
        hb_socketClose( hIdle )
    ENDIF
    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 0 }, 1000 ), ;
        "worker slot becomes available after disconnect", @nFailures, @nChecks )
    mtassert( mtechomatches( mtechorequest( hServer[ "port" ], 99 ), 99 ), ;
        "server accepts work after capacity becomes available", @nFailures, @nChecks )
    mtassert( hbbridgeserverstop( hServer ), "single-worker server stops", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE mtgracefulstop( nFailures, nChecks )

    LOCAL hServer := hbbridgeserverstart( 0, 2 )
    LOCAL hIdle, hStop, hResponse, lStopped := .F.

    mtassert( HB_ISHASH( hServer ), "shutdown test server starts", @nFailures, @nChecks )
    IF ! HB_ISHASH( hServer )
        RETURN
    ENDIF

    hIdle := mtconnect( hServer[ "port" ] )
    mtassert( ! Empty( hIdle ), "in-flight shutdown client connects", @nFailures, @nChecks )
    IF Empty( hIdle )
        hbbridgeserverstop( hServer )
        RETURN
    ENDIF
    mtassert( mtwait( {|| hbbridgeserveractive( hServer ) == 1 }, 1000 ), ;
        "shutdown starts with an admitted worker", @nFailures, @nChecks )

    hStop := hb_threadStart( @hbbridgeserverstop(), hServer )
    mtassert( mtwait( {|| ! hbbridgeserverrunning( hServer ) }, 1000 ), ;
        "shutdown marks listener as stopped", @nFailures, @nChecks )
    mtassert( mtwait( {|| mtconnectionrefused( hServer[ "port" ] ) }, 1000 ), ;
        "shutdown refuses new connections before draining finishes", @nFailures, @nChecks )
    mtassert( hb_threadWait( hStop, 0 ) == 0, ;
        "shutdown waits for its in-flight worker", @nFailures, @nChecks )

    hResponse := mtexchange( hIdle, mtechojson( 123 ) )
    hb_socketClose( hIdle )
    mtassert( mtechomatches( hResponse, 123 ), ;
        "admitted request completes during graceful shutdown", @nFailures, @nChecks )
    mtassert( mtjoin( hStop, @lStopped ), "shutdown thread finishes after worker drains", @nFailures, @nChecks )
    mtassert( lStopped == .T., "graceful shutdown reports success", @nFailures, @nChecks )
    mtassert( hbbridgeserveractive( hServer ) == 0, "shutdown leaves no active workers", @nFailures, @nChecks )
    mtassert( mtconnectionrefused( hServer[ "port" ] ), "stopped port refuses new clients", @nFailures, @nChecks )

RETURN

STATIC FUNCTION mtconnect( nPort )

    LOCAL hSocket := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_IP )

    IF ! Empty( hSocket )
        IF ! hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 1000 )
            hb_socketClose( hSocket )
            hSocket := NIL
        ENDIF
    ENDIF

RETURN hSocket

STATIC FUNCTION mtconnectionrefused( nPort )

    LOCAL hSocket := mtconnect( nPort )

    IF ! Empty( hSocket )
        hb_socketClose( hSocket )
        RETURN .F.
    ENDIF

RETURN .T.

STATIC FUNCTION mtechojson( nIndex )

    LOCAL hParams := { "id" => nIndex, "payload" => Replicate( hb_ntos( nIndex ) + "-", 30 ) }

RETURN hb_jsonEncode( { "service" => "Echo", "params" => hParams } )

STATIC FUNCTION mtechorequest( nPort, nIndex )
RETURN mtrequest( nPort, mtechojson( nIndex ) )

STATIC FUNCTION mtaddonrequest( nPort, nIndex )
RETURN mtrequest( nPort, hb_jsonEncode( { "service" => "ADDON.Execute", ;
    "params" => { "module" => "hbbridge_mt_isolation.hrb", "params" => { "id" => nIndex } } } ) )

FUNCTION mtrequest( nPort, cJson, cSignature )

    LOCAL hSocket := mtconnect( nPort ), hResponse := NIL

    IF ! Empty( hSocket )
        hResponse := mtexchange( hSocket, cJson, cSignature )
        hb_socketClose( hSocket )
    ENDIF

RETURN hResponse

STATIC FUNCTION mtexchange( hSocket, cJson, cSignature )

    LOCAL cFrame, nZipError, cCompressed
    LOCAL cResponse := "", cChunk, nReceived, nDeadline := hbbridgemonotonicms() + MT_TIMEOUT_MS
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
    DO WHILE hbbridgemonotonicms() < nDeadline
        cChunk := Space( 4096 )
        nReceived := hb_socketRecv( hSocket, @cChunk, hb_BLen( cChunk ), 0, ;
            Max( 1, nDeadline - hbbridgemonotonicms() ) )
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

STATIC FUNCTION mtechomatches( hResponse, nIndex )

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

STATIC FUNCTION mtaddonmatches( hResponse, nIndex )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "id" ) .OR. ! hb_HHasKey( hResponse, "counter" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "id" ] == nIndex .AND. hResponse[ "counter" ] == 1

STATIC FUNCTION mtiserror( hResponse )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .F.

STATIC FUNCTION mtjoin( hThread, xResult )

    IF Empty( hThread )
        RETURN .F.
    ENDIF
    IF hb_threadWait( hThread, 7 ) == 0
        hb_threadQuitRequest( hThread )
        hb_threadDetach( hThread )
        RETURN .F.
    ENDIF

RETURN hb_threadJoin( hThread, @xResult )

STATIC FUNCTION mtwait( bCondition, nTimeout )

    LOCAL nDeadline := hbbridgemonotonicms() + nTimeout

    DO WHILE hbbridgemonotonicms() < nDeadline
        IF Eval( bCondition )
            RETURN .T.
        ENDIF
        hb_idleSleep( 0.01 )
    ENDDO

RETURN Eval( bCondition )

STATIC PROCEDURE mtassert( lCondition, cMessage, nFailures, nChecks )

    nChecks++
    IF lCondition
        ? "PASS:", cMessage
    ELSE
        nFailures++
        ? "FAIL:", cMessage
    ENDIF

RETURN
