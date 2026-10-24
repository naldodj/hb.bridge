/* Released to Public Domain. */
#include "hbsocket.ch"

REQUEST HB_GT_STD_DEFAULT
REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE Main()
    LOCAL cSmall := hb_HexToStr( "61C3A900E6BCA2F09F988062" )
    LOCAL cLarge := Replicate( "0123456789abcdef", 4 * 1024 * 1024 )
    LOCAL hState, hThread, hSocket, hResponse, hError
    LOCAL nChecks := 0, nFailures := 0, nPort, nStarted
    LOCAL oServer

    hb_cdpSelect( "UTF8EX" )
    SendConfigTests( @nChecks, @nFailures )
    hState := SendState()
    oServer := UHttpdNew()
    nPort := SendFreePort()
    hThread := SendStart( oServer, nPort, 0, 7, cSmall, cLarge, hState )
    SendAssert( hb_mutexSubscribe( hState[ "ready" ], 5 ), "native server starts with no deadline and seven-byte chunks", @nChecks, @nFailures )
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hSocket := SendConnect( nPort )
        SendRequest( hSocket, "/small", .F. )
        hResponse := SendRead( hSocket )
        IF hResponse[ "body" ] != cSmall
            ? "Native fixture response:", hResponse[ "headers" ]
        ENDIF
        SendAssert( hResponse[ "body" ] == cSmall .AND. hResponse[ "length" ] == hb_BLen( cSmall ), ;
            "bounded chunks preserve UTF-8, supplementary characters and embedded NUL bytes", @nChecks, @nFailures )
        SendRequest( hSocket, "/small", .T. )
        hResponse := SendRead( hSocket )
        SendAssert( hResponse[ "body" ] == cSmall, "completed send restores plain keep-alive reads", @nChecks, @nFailures )
    RECOVER USING hError
        SendAssert( .F., "native chunk test exception: " + hError:Description, @nChecks, @nFailures )
    ALWAYS
        IF ! Empty( hSocket )
            hb_socketClose( hSocket )
        ENDIF
        oServer:Stop()
        hb_threadJoin( hThread )
    END SEQUENCE

    hState := SendState()
    oServer := UHttpdNew()
    nPort := SendFreePort()
    hThread := SendStart( oServer, nPort, 250, 65536, cSmall, cLarge, hState )
    SendAssert( hb_mutexSubscribe( hState[ "ready" ], 5 ), "deadline server starts with one worker", @nChecks, @nFailures )
    hSocket := NIL
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hSocket := SendConnect( nPort )
        hb_socketSetRcvBufSize( hSocket, 1024 )
        nStarted := HBBridgeMonotonicMs()
        SendRequest( hSocket, "/large", .F. )
        SendRequest( hSocket, "/small", .T. )
        SendAssert( hb_mutexSubscribe( hState[ "timeout" ], 3 ) .AND. ;
            HBBridgeMonotonicMs() - nStarted < 2000, ;
            "stalled reader reaches the 250ms total send deadline within two seconds", @nChecks, @nFailures )
        SendAssert( hb_mutexEval( hState[ "mutex" ], {|| hState[ "small" ] == 0 .AND. hState[ "access" ] == 0 } ), ;
            "incomplete send neither dispatches its pipelined request nor logs a complete response", @nChecks, @nFailures )
        hb_socketClose( hSocket )
        hSocket := SendConnect( nPort )
        SendRequest( hSocket, "/small", .T. )
        hResponse := SendRead( hSocket )
        SendAssert( hResponse[ "body" ] == cSmall, "single worker accepts a fresh request after the send timeout", @nChecks, @nFailures )
    RECOVER USING hError
        SendAssert( .F., "native deadline test exception: " + hError:Description, @nChecks, @nFailures )
    ALWAYS
        IF ! Empty( hSocket )
            hb_socketClose( hSocket )
        ENDIF
        oServer:Stop()
        hb_threadJoin( hThread )
    END SEQUENCE

    hState := SendState()
    oServer := UHttpdNew()
    nPort := SendFreePort()
    hThread := SendStart( oServer, nPort, 0, 65536, cSmall, cLarge, hState )
    SendAssert( hb_mutexSubscribe( hState[ "ready" ], 5 ), "stop test starts with the send deadline disabled", @nChecks, @nFailures )
    hSocket := SendConnect( nPort )
    hb_socketSetRcvBufSize( hSocket, 1024 )
    SendRequest( hSocket, "/large", .F. )
    SendAssert( hb_mutexSubscribe( hState[ "large" ], 3 ), "large response handler starts before coordinated stop", @nChecks, @nFailures )
    SendAssert( hb_socketSelectRead( hSocket, 1000 ) > 0, "large response begins sending to the stalled reader", @nChecks, @nFailures )
    nStarted := HBBridgeMonotonicMs()
    oServer:Stop()
    hb_threadJoin( hThread )
    SendAssert( HBBridgeMonotonicMs() - nStarted < 2500, "coordinated stop cancels a stalled sender within 2.5 seconds", @nChecks, @nFailures )
    hb_socketClose( hSocket )
    ? "Native HTTP send checks:", nChecks, "failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )
    RETURN

STATIC PROCEDURE SendConfigTests( nChecks, nFailures )
    LOCAL hCase
    LOCAL oServer

    FOR EACH hCase IN { { "SendTimeout" => -1 }, { "SendTimeout" => 1.5 }, ;
        { "SendTimeout" => 2147483648 }, { "SendTimeout" => "250" }, ;
        { "SendChunkSize" => 0 }, { "SendChunkSize" => 1.5 }, { "SendChunkSize" => 2147483648 } }
        oServer := UHttpdNew()
        SendAssert( ! oServer:Run( hCase ) .AND. ! Empty( oServer:cError ), ;
            "invalid native send configuration is rejected: " + hb_ValToExp( hCase ), @nChecks, @nFailures )
    NEXT
    RETURN

STATIC FUNCTION SendState()
    RETURN { "ready" => hb_mutexCreate(), "timeout" => hb_mutexCreate(), "large" => hb_mutexCreate(), ;
        "mutex" => hb_mutexCreate(), "small" => 0, "access" => 0 }

STATIC FUNCTION SendStart( oServer, nPort, nTimeout, nChunk, cSmall, cLarge, hState )
    LOCAL hConfig := { "Port" => nPort, "BindAddress" => "127.0.0.1", "MaxWorkers" => 1, ;
        "FirewallFilter" => "", ;
        "SendTimeout" => nTimeout, "SendChunkSize" => nChunk, ;
        "Ready" => {|| hb_mutexNotify( hState[ "ready" ], .T. ) }, ;
        "LogAccess" => {|| hb_mutexEval( hState[ "mutex" ], {|| hState[ "access" ]++ } ) }, ;
        "Trace" => {| cEvent | iif( cEvent == "send timeout:", hb_mutexNotify( hState[ "timeout" ], .T. ), NIL ) }, ;
        "Mount" => { "/small" => {|| SendSmall( hState, cSmall ) }, ;
            "/large" => {|| hb_mutexNotify( hState[ "large" ], .T. ), cLarge } } }
    RETURN hb_threadStart( {|| oServer:Run( hConfig ) } )

STATIC FUNCTION SendSmall( hState, cBody )
    hb_mutexEval( hState[ "mutex" ], {|| hState[ "small" ]++ } )
    RETURN cBody

STATIC FUNCTION SendFreePort()
    LOCAL hSocket := hb_socketOpen()
    LOCAL nPort

    hb_socketBind( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", 0 } )
    nPort := hb_socketGetSockName( hSocket )[ HB_SOCKET_ADINFO_PORT ]
    hb_socketClose( hSocket )
    RETURN nPort

STATIC FUNCTION SendConnect( nPort )
    LOCAL hSocket := hb_socketOpen()

    IF ! hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 1000 )
        Break( ErrorNew( "HTTP send probe", 0, 0, "Loopback connection failed" ) )
    ENDIF
    RETURN hSocket

STATIC PROCEDURE SendRequest( hSocket, cPath, lClose )
    LOCAL cRequest := "GET " + cPath + " HTTP/1.1" + Chr( 13 ) + Chr( 10 ) + ;
        "Host: localhost" + Chr( 13 ) + Chr( 10 ) + "Connection: " + ;
        iif( lClose, "close", "keep-alive" ) + Chr( 13 ) + Chr( 10 ) + Chr( 13 ) + Chr( 10 )

    IF hb_socketSend( hSocket, cRequest,,, 1000 ) != hb_BLen( cRequest )
        Break( ErrorNew( "HTTP send probe", 0, 0, "Loopback request send failed" ) )
    ENDIF
    RETURN

STATIC FUNCTION SendRead( hSocket )
    LOCAL cResponse := "", cBuffer := Space( 4096 ), cHeaders, cLine
    LOCAL nRead, nBoundary, nLength := NIL, nStarted := HBBridgeMonotonicMs()

    DO WHILE HBBridgeMonotonicMs() - nStarted < 3000
        nRead := hb_socketRecv( hSocket, @cBuffer,,, 1000 )
        IF nRead <= 0
            EXIT
        ENDIF
        cResponse += hb_BLeft( cBuffer, nRead )
        nBoundary := hb_BAt( Chr( 13 ) + Chr( 10 ) + Chr( 13 ) + Chr( 10 ), cResponse )
        IF nBoundary > 0
            cHeaders := hb_BLeft( cResponse, nBoundary - 1 )
            FOR EACH cLine IN hb_ATokens( cHeaders, Chr( 13 ) + Chr( 10 ) )
                IF Lower( Left( cLine, 15 ) ) == "content-length:"
                    nLength := Val( SubStr( cLine, 16 ) )
                ENDIF
            NEXT
            IF nLength != NIL .AND. hb_BLen( cResponse ) >= nBoundary + 3 + nLength
                RETURN { "body" => hb_BSubStr( cResponse, nBoundary + 4 ), "length" => nLength, "headers" => cHeaders }
            ENDIF
        ENDIF
    ENDDO
    RETURN { "body" => NIL, "length" => NIL, "headers" => hb_BLeft( cResponse, 512 ) }

STATIC PROCEDURE SendAssert( lSuccess, cMessage, nChecks, nFailures )
    nChecks++
    IF lSuccess
        ? "PASS", cMessage
    ELSE
        nFailures++
        ? "FAIL", cMessage
    ENDIF
    RETURN
