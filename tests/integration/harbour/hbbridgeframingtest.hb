#include "hbsocket.ch"

PROCEDURE M2FramingTests( nFailures, nChecks )

    LOCAL cData := M2VariedData( 240000 ), cJson, cFrame, cZip, cDecoded, nStatus
    LOCAL cPayload, cBad, hServer, hResponse, nWireSize, aInvalid, cInvalid, nPayloadSize

    cJson := hb_jsonEncode( { "service" => "Echo", "params" => { "data" => cData } } )
    cFrame := "HBBRIDGE/1|JSON|" + hb_ntos( hb_BLen( cJson ) ) + hb_BChar( 10 ) + cJson
    cZip := hb_gzCompress( cFrame )
    M1Assert( hb_BLen( cZip ) > 65535, "M2 varied gzip exceeds a 65535-byte socket read", @nFailures, @nChecks )
    M2CompressorTests( cFrame, @nFailures, @nChecks )

    cDecoded := M2Decode( cZip, 1, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == 1 .AND. cDecoded == cFrame, ;
        "M2 decoder accepts byte-by-byte gzip header, body and trailer", @nFailures, @nChecks )
    cDecoded := M2Decode( cZip, 4093, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == 1 .AND. cDecoded == cFrame, ;
        "M2 decoder preserves state across irregular input chunks", @nFailures, @nChecks )
    M2Decode( cZip, 4093, hb_BLen( cFrame ) - 1, @nStatus )
    M1Assert( nStatus == -1, "M2 expansion over budget is rejected during inflate", @nFailures, @nChecks )
    M2Decode( hb_BLeft( cZip, hb_BLen( cZip ) - 1 ), 4093, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == 0, "M2 missing gzip trailer does not complete a message", @nFailures, @nChecks )
    cBad := cZip
    hb_BPoke( @cBad, hb_BLen( cBad ) - 7, hb_bitXor( hb_BCode( hb_BSubStr( cBad, hb_BLen( cBad ) - 7, 1 ) ), 1 ) )
    M2Decode( cBad, 4093, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == -1, "M2 invalid gzip CRC is rejected", @nFailures, @nChecks )
    M2Decode( cZip + "extra", hb_BLen( cZip ) + 5, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == -1, "M2 trailing bytes in a compressed input unit are rejected", @nFailures, @nChecks )
    M2Decode( cZip + cZip, hb_BLen( cZip ) * 2, hb_BLen( cFrame ) * 2, @nStatus )
    M1Assert( nStatus == -1, "M2 coalesced gzip members are rejected in the one-call profile", @nFailures, @nChecks )
    M2Decode( hb_ZCompress( cFrame ), 97, hb_BLen( cFrame ), @nStatus )
    M1Assert( nStatus == -1, "M2 rejects zlib wrapper because the contract requires gzip", @nFailures, @nChecks )

    M1Assert( HBBridgeParseFrame( cFrame, @cPayload ) .AND. ;
        cPayload == cJson, ;
        "M2 parses a large body without confusing it with the header limit", @nFailures, @nChecks )
    M1Assert( HBBridgeParseHeader( "HBBRIDGE/1|JSON|100000000" + hb_BChar( 10 ), @nPayloadSize ) > 0 .AND. ;
        nPayloadSize == 100000000, "M2 accepts a nine-digit size without allocating its body", @nFailures, @nChecks )
    M1Assert( HBBridgeParseHeader( "HBBRIDGE/1|JSON|" + hb_ntos( HBBridgeRuntimeLimits()[ "stringBytesMax" ] ) + ;
        hb_BChar( 10 ), @nPayloadSize ) == -1, "M2 rejects native length overflow including the header", @nFailures, @nChecks )
    M1Assert( ! HBBridgeParseFrame( cJson, @cPayload ), "M2 rejects JSON without its protocol frame", @nFailures, @nChecks )
    aInvalid := { "HBBRIDGE/1|JSON|2x", "HBBRIDGE/1|JSON|+2", "HBBRIDGE/1|JSON| 2", ;
        "HBBRIDGE/1|JSON|2.0", "HBBRIDGE/1|JSON|0", "HBBRIDGE/1|JSON|16777217", ;
        "HBBRIDGE/1|JSON|000000002", "HBBRIDGE/1|JSONx|2", "HBBRIDGE/1|JSON|2|extra", ;
        "HBBRIDGE/1|JSON|" + Space( 128 ), "HBS1|JSON|2", "HBBRIDGE/2|JSON|2" }
    FOR EACH cInvalid IN aInvalid
        M1Assert( ! HBBridgeParseFrame( cInvalid + hb_BChar( 10 ) + "{}", @cPayload ), ;
            "M2 rejects malformed header " + hb_BLeft( cInvalid, 45 ), @nFailures, @nChecks )
    NEXT
    M1Assert( ! HBBridgeParseFrame( "HBBRIDGE/1|JSON|3" + hb_BChar( 10 ) + "{}", @cPayload ), ;
        "M2 rejects a shorter body than declared", @nFailures, @nChecks )
    M1Assert( ! HBBridgeParseFrame( "HBBRIDGE/1|JSON|1" + hb_BChar( 10 ) + "{}", @cPayload ), ;
        "M2 rejects a longer body than declared", @nFailures, @nChecks )
    M1Assert( ! HBBridgeParseFrame( "HBBRIDGE/1|JSON|2", @cPayload ), ;
        "M2 rejects a header without its terminator", @nFailures, @nChecks )

    hServer := HBBridgeServerStart( 0, 4 )
    M1Assert( HB_ISHASH( hServer ), "M2 framing server starts on an isolated port", @nFailures, @nChecks )
    IF ! HB_ISHASH( hServer )
        RETURN
    ENDIF
    hResponse := M2Exchange( hServer[ "port" ], cZip, @nWireSize )
    M1Assert( M2EchoMatches( hResponse, cData ), "M2 fragmented gzip Echo preserves every byte", @nFailures, @nChecks )
    M1Assert( nWireSize > 65535, "M2 response also exceeds 65535 compressed bytes", @nFailures, @nChecks )
    FOR EACH cInvalid IN { hb_gzCompress( "HBS1|JSON|2" + hb_BChar( 10 ) + "{}" ), ;
        hb_gzCompress( "HBBRIDGE/2|JSON|2" + hb_BChar( 10 ) + "{}" ), ;
        hb_gzCompress( cJson ), hb_ZCompress( cFrame ) }
        hResponse := M2Exchange( hServer[ "port" ], cInvalid, @nWireSize )
        M1Assert( hResponse == NIL .AND. nWireSize == 0, "M2 unsupported wire format closes before dispatch", @nFailures, @nChecks )
    NEXT
    hResponse := M2Exchange( hServer[ "port" ], cBad, @nWireSize )
    M1Assert( hResponse == NIL .AND. nWireSize == 0, "M2 invalid CRC is closed before dispatch", @nFailures, @nChecks )
    hResponse := M2Exchange( hServer[ "port" ], hb_BLeft( cZip, hb_BLen( cZip ) - 1 ), @nWireSize )
    M1Assert( hResponse == NIL .AND. nWireSize == 0, "M2 premature TCP EOF rejects an incomplete gzip trailer", @nFailures, @nChecks )
    hResponse := MTRequest( hServer[ "port" ], '{"service":"Echo","params":{"data":"still healthy"}}' )
    M1Assert( M2EchoMatches( hResponse, "still healthy" ), "M2 server remains usable after invalid compressed messages", @nFailures, @nChecks )
    hResponse := MTRequest( hServer[ "port" ], '{"service":"ADDON.examples/hbbridgesampleaddon.hb","params":{}}' )
    M1Assert( HB_ISHASH( hResponse ) .AND. hResponse[ "code" ] == "SERVICE_NOT_FOUND", ;
        "M2 rejects unregistered addon aliases through the shared service contract", @nFailures, @nChecks )
    M2LargeEcho( hServer[ "port" ], cData, @nFailures, @nChecks )
    M1Assert( HBBridgeServerStop( hServer ), "M2 framing server releases all workers", @nFailures, @nChecks )
    M2PolicyTests( cData, cJson, cZip, @nFailures, @nChecks )
    M2SlowClient( cZip, @nFailures, @nChecks )

RETURN

STATIC PROCEDURE M2SlowClient( cZip, nFailures, nChecks )

    LOCAL hSocket := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_IP )
    LOCAL nStarted, nReceived, nError, cByte := Space( 1 ), lSent
    LOCAL hServer := HBBridgeServerStart( 0, 1, NIL, NIL, NIL, ;
        { "protheusTimeoutMs" => 1500, "protheusReadChunkBytes" => 1 } )

    IF ! HB_ISHASH( hServer )
        M1Assert( .F., "M2 explicit-deadline server starts", @nFailures, @nChecks )
        IF ! Empty( hSocket )
            hb_socketClose( hSocket )
        ENDIF
        RETURN
    ENDIF
    IF ! Empty( hSocket )
        IF hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", hServer[ "port" ] }, 1000 )
            nStarted := HBBridgeMonotonicMs()
            IF hb_socketSend( hSocket, hb_BLeft( cZip, 1 ), NIL, 0, 1000 ) == 1
                hb_idleSleep( 0.6 )
                lSent := hb_socketSend( hSocket, hb_BSubStr( cZip, 2, 1 ), NIL, 0, 1000 ) == 1
                nReceived := hb_socketRecv( hSocket, @cByte, 1, 0, 1400 )
                nError := hb_socketGetError()
                M1Assert( lSent .AND. ( nReceived == 0 .OR. ;
                    ( nReceived < 0 .AND. nError != HB_SOCKET_ERR_TIMEOUT ) ) .AND. ;
                    HBBridgeMonotonicMs() - nStarted < 2100, ;
                    "M2 receive deadline is not restarted by a slow client's next fragment", @nFailures, @nChecks )
            ELSE
                M1Assert( .F., "M2 slow-client first fragment is sent", @nFailures, @nChecks )
            ENDIF
        ELSE
            M1Assert( .F., "M2 slow client connects", @nFailures, @nChecks )
        ENDIF
        hb_socketClose( hSocket )
    ELSE
        M1Assert( .F., "M2 slow-client socket opens", @nFailures, @nChecks )
    ENDIF
    M1Assert( HBBridgeServerStop( hServer ), "M2 deadline server releases its worker", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE M2LargeEcho( nPort, cSeed, nFailures, nChecks )

    LOCAL cData := Replicate( cSeed, 100 )
    LOCAL cJson := hb_jsonEncode( { "service" => "Echo", "params" => { "data" => cData } } )
    LOCAL cZip := hb_gzCompress( "HBBRIDGE/1|JSON|" + hb_ntos( hb_BLen( cJson ) ) + hb_BChar( 10 ) + cJson )
    LOCAL hResponse, nWireSize

    M1Assert( hb_BLen( cJson ) > 16777216 .AND. hb_BLen( cZip ) > 16777216, ;
        "M2 real request exceeds 16 MiB both before and after gzip", @nFailures, @nChecks )
    hResponse := M2Exchange( nPort, cZip, @nWireSize )
    M1Assert( M2EchoMatches( hResponse, cData ), ;
        "M2 default policy echoes 24 million data bytes exactly", @nFailures, @nChecks )
    M1Assert( nWireSize > 16777216, "M2 response gzip also exceeds the former wire ceiling", @nFailures, @nChecks )

RETURN

STATIC PROCEDURE M2PolicyTests( cData, cJson, cZip, nFailures, nChecks )

    LOCAL hServer, hResponse, nWireSize
    LOCAL aPolicies := { { "protheusMaxPayloadBytes" => 1000 }, ;
        { "protheusMaxWireBytes" => 1000 }, { "protheusMaxPayloadBytes" => hb_BLen( cJson ) }, ;
        { "protheusMaxWireBytes" => hb_BLen( cZip ) } }
    LOCAL aNames := { "payload budget rejects oversized input", "wire budget rejects oversized input", ;
        "payload budget also constrains the larger Echo response", ;
        "wire budget also constrains the larger Echo response" }, hPolicy, nIndex

    M1Assert( HBBridgeServerStart( 0, 1, NIL, NIL, NIL, { "protheusReadChunkBytes" => 0 } ) == NIL, ;
        "M2 direct transport API rejects invalid policies", @nFailures, @nChecks )
    FOR nIndex := 1 TO Len( aPolicies )
        hPolicy := aPolicies[ nIndex ]
        hServer := HBBridgeServerStart( 0, 1, NIL, NIL, NIL, hPolicy )
        M1Assert( HB_ISHASH( hServer ), "M2 configured budget server starts", @nFailures, @nChecks )
        IF HB_ISHASH( hServer )
            hResponse := M2Exchange( hServer[ "port" ], cZip, @nWireSize )
            IF nIndex == 4
                M1Assert( hResponse == NIL .AND. nWireSize > 0 .AND. nWireSize <= hb_BLen( cZip ), ;
                    "M2 " + aNames[ nIndex ], @nFailures, @nChecks )
            ELSE
                M1Assert( hResponse == NIL .AND. nWireSize == 0, "M2 " + aNames[ nIndex ], @nFailures, @nChecks )
            ENDIF
            M1Assert( HBBridgeServerStop( hServer ), "M2 budget server releases its worker", @nFailures, @nChecks )
        ENDIF
    NEXT
    hServer := HBBridgeServerStart( 0, 1, NIL, NIL, NIL, ;
        { "protheusReadChunkBytes" => 1024, "protheusTimeoutMs" => 0 } )
    M1Assert( HB_ISHASH( hServer ), "M2 unlimited deadline with a small IO buffer starts", @nFailures, @nChecks )
    IF HB_ISHASH( hServer )
        hResponse := M2Exchange( hServer[ "port" ], cZip, @nWireSize )
        M1Assert( M2EchoMatches( hResponse, cData ), ;
            "M2 1024-byte IO buffer does not limit message size", @nFailures, @nChecks )
        M1Assert( HBBridgeServerStop( hServer ), "M2 unlimited deadline server releases its worker", @nFailures, @nChecks )
    ENDIF

RETURN

STATIC PROCEDURE M2CompressorTests( cFrame, nFailures, nChecks )

    LOCAL nStatus, cZip, pEncoder, aEncoded, cPart

    cZip := M2Encode( hb_BLeft( cFrame, 513 ), 1, @nStatus )
    M1Assert( nStatus == 1 .AND. hb_ZUncompress( cZip ) == hb_BLeft( cFrame, 513 ), ;
        "M2 incremental compressor accepts byte-by-byte input", @nFailures, @nChecks )
    cZip := M2Encode( cFrame, 4093, @nStatus )
    M1Assert( nStatus == 1 .AND. hb_ZUncompress( cZip ) == cFrame, ;
        "M2 incremental compressor interoperates with the native reference inflater", @nFailures, @nChecks )
    pEncoder := HBBridgeDeflateOpen()
    aEncoded := HBBridgeDeflateFeed( pEncoder, "", .T. )
    cZip := ""
    FOR EACH cPart IN aEncoded[ 2 ]
        cZip += cPart
    NEXT
    M1Assert( aEncoded[ 1 ] == 1 .AND. aEncoded[ 3 ] == 0 .AND. hb_BLen( cZip ) > 0 .AND. ;
        hb_ZUncompress( cZip ) == "", "M2 final empty input emits a complete gzip", @nFailures, @nChecks )
    aEncoded := HBBridgeDeflateFeed( pEncoder, "extra", .F. )
    M1Assert( aEncoded[ 1 ] == -1 .AND. Empty( aEncoded[ 2 ] ), ;
        "M2 compressor rejects input after completion", @nFailures, @nChecks )
    M1Assert( HBBridgeDeflateClose( pEncoder ) .AND. HBBridgeDeflateClose( pEncoder ), ;
        "M2 compressor cleanup is idempotent", @nFailures, @nChecks )

RETURN

STATIC FUNCTION M2Encode( cInput, nChunkSize, nStatus )

    LOCAL pEncoder := HBBridgeDeflateOpen(), nOffset := 1, aEncoded, cPart, cZip := "", nCount

    nStatus := 0
    DO WHILE nOffset <= hb_BLen( cInput ) .AND. nStatus == 0
        nCount := Min( nChunkSize, hb_BLen( cInput ) - nOffset + 1 )
        aEncoded := HBBridgeDeflateFeed( pEncoder, hb_BSubStr( cInput, nOffset, nCount ), ;
            nOffset + nCount > hb_BLen( cInput ) )
        nStatus := aEncoded[ 1 ]
        FOR EACH cPart IN aEncoded[ 2 ]
            cZip += cPart
        NEXT
        nOffset += nCount
    ENDDO
    HBBridgeDeflateClose( pEncoder )

RETURN cZip

STATIC FUNCTION M2VariedData( nSize )

    LOCAL cData := Space( nSize ), nIndex, nSeed := 12345

    FOR nIndex := 1 TO nSize
        nSeed := ( nSeed * 48271 ) % 2147483647
        hb_BPoke( @cData, nIndex, 48 + ( nSeed % 74 ) )
    NEXT

RETURN cData

STATIC FUNCTION M2Decode( cZip, nChunkSize, nLimit, nStatus )

    LOCAL pDecoder := HBBridgeInflateOpen( nLimit ), nOffset := 1, aDecoded, cPart, cDecoded := ""

    nStatus := 0
    DO WHILE nOffset <= hb_BLen( cZip ) .AND. nStatus == 0
        aDecoded := HBBridgeInflateFeed( pDecoder, hb_BSubStr( cZip, nOffset, nChunkSize ) )
        nStatus := aDecoded[ 1 ]
        FOR EACH cPart IN aDecoded[ 2 ]
            cDecoded += cPart
        NEXT
        nOffset += nChunkSize
    ENDDO
    HBBridgeInflateClose( pDecoder )

RETURN cDecoded

/* Independent reference receiver: read FIN, inflate once, compare exact framing. */
STATIC FUNCTION M2Exchange( nPort, cZip, nWireSize )

    LOCAL hSocket := hb_socketOpen( HB_SOCKET_AF_INET, HB_SOCKET_PT_STREAM, HB_SOCKET_IPPROTO_IP )
    LOCAL nOffset := 1, nCount, nSent, nReceived, nHeaderEnd, cChunk, cWire := "", cFrame
    LOCAL cJson, hResponse := NIL, nDeadline := HBBridgeMonotonicMs() + 30000

    nWireSize := 0
    IF Empty( hSocket )
        RETURN NIL
    ENDIF
    IF ! hb_socketConnect( hSocket, { HB_SOCKET_AF_INET, "127.0.0.1", nPort }, 1000 )
        hb_socketClose( hSocket )
        RETURN NIL
    ENDIF
    DO WHILE nOffset <= hb_BLen( cZip )
        /* Split gzip header and final trailer bytes, not just the JSON body. */
        nCount := Min( 4093, hb_BLen( cZip ) - nOffset + 1 )
        IF nOffset <= 10 .OR. hb_BLen( cZip ) - nOffset < 8
            nCount := 1
        ELSEIF nOffset + nCount > hb_BLen( cZip ) - 7
            nCount := hb_BLen( cZip ) - 7 - nOffset
        ENDIF
        nSent := hb_socketSend( hSocket, hb_BSubStr( cZip, nOffset, nCount ), NIL, 0, 1000 )
        IF nSent <= 0
            EXIT
        ENDIF
        nOffset += nSent
        IF nCount == 1
            hb_idleSleep( 0.002 )
        ENDIF
    ENDDO
    hb_socketShutdown( hSocket, HB_SOCKET_SHUT_WR )
    DO WHILE HBBridgeMonotonicMs() < nDeadline
        cChunk := Space( 65536 )
        nReceived := hb_socketRecv( hSocket, @cChunk, hb_BLen( cChunk ), 0, Max( 1, nDeadline - HBBridgeMonotonicMs() ) )
        IF nReceived <= 0
            EXIT
        ENDIF
        cWire += hb_BLeft( cChunk, nReceived )
    ENDDO
    hb_socketClose( hSocket )
    nWireSize := hb_BLen( cWire )
    IF nOffset <= hb_BLen( cZip ) .OR. nReceived != 0 .OR. Empty( cWire )
        RETURN NIL
    ENDIF
    cFrame := hb_ZUncompress( cWire )
    IF ! HB_ISSTRING( cFrame )
        RETURN NIL
    ENDIF
    nHeaderEnd := hb_BAt( hb_BChar( 10 ), cFrame )
    IF nHeaderEnd <= 0
        RETURN NIL
    ENDIF
    cJson := hb_BSubStr( cFrame, nHeaderEnd + 1 )
    IF ! ( hb_BLeft( cFrame, nHeaderEnd ) == "HBBRIDGE/1|JSON|" + hb_ntos( hb_BLen( cJson ) ) + hb_BChar( 10 ) )
        RETURN NIL
    ENDIF
    IF hb_jsonDecode( cJson, @hResponse ) != hb_BLen( cJson )
        RETURN NIL
    ENDIF

RETURN hResponse

STATIC FUNCTION M2EchoMatches( hResponse, cData )

    IF ! HB_ISHASH( hResponse )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse, "success" ) .OR. ! hb_HHasKey( hResponse, "params" )
        RETURN .F.
    ENDIF
    IF ! HB_ISHASH( hResponse[ "params" ] )
        RETURN .F.
    ENDIF
    IF ! hb_HHasKey( hResponse[ "params" ], "data" )
        RETURN .F.
    ENDIF

RETURN hResponse[ "success" ] == .T. .AND. hResponse[ "params" ][ "data" ] == cData
