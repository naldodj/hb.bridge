/* Released to Public Domain. */
#include "hbbridge.h"

/* Copy only transport settings; zero budgets do not impose application caps. */
FUNCTION hbbridgeprotheuspolicy( hOptions )

    LOCAL hPolicy := { "protheusMaxPayloadBytes" => 0, "protheusMaxWireBytes" => 0, ;
        "protheusReadChunkBytes" => HBBRIDGE_IO_CHUNK_DEFAULT_BYTES, ;
        "protheusTimeoutMs" => HBBRIDGE_IO_TIMEOUT_DEFAULT_MS }
    LOCAL hRuntime := hbbridgeruntimelimits(), cKey, nValue, nMaximum

    IF hOptions != NIL .AND. ! HB_ISHASH( hOptions )
        RETURN NIL
    ENDIF
    FOR EACH cKey IN hb_HKeys( hPolicy )
        IF hOptions != NIL .AND. hb_HHasKey( hOptions, cKey )
            hPolicy[ cKey ] := hOptions[ cKey ]
        ENDIF
        nValue := hPolicy[ cKey ]
        nMaximum := hRuntime[ iif( cKey == "protheusReadChunkBytes", "socketChunkBytesMax", "stringBytesMax" ) ]
        IF cKey == "protheusReadChunkBytes"
            nMaximum := Min( nMaximum, hRuntime[ "zlibChunkBytesMax" ] )
        ENDIF
        IF ! HB_ISNUMERIC( nValue )
            RETURN NIL
        ENDIF
        IF ! HBBridgeIntegerValid( nValue, nMaximum ) .OR. ;
            ( cKey == "protheusReadChunkBytes" .AND. nValue == 0 )
            RETURN NIL
        ENDIF
    NEXT

RETURN hPolicy

FUNCTION receiverequest( hSocket, cPayload as character, hOptions )

    LOCAL hPolicy := hbbridgeprotheuspolicy( hOptions ), cBuffer := "", cChunk, cPart, aDecoded
    LOCAL nBytesRead, nWireBytes := 0, aDeadline, nWait, nHeaderEnd := 0, nPayloadBytes := 0
    LOCAL nFrameLimit, nMaxHeader := headersizemaximum(), pDecoder, lComplete := .F.

    cPayload := ""
    IF hPolicy == NIL
        RETURN .F.
    ENDIF
    aDeadline := iodeadline( hPolicy[ "protheusTimeoutMs" ] )
    nFrameLimit := hPolicy[ "protheusMaxPayloadBytes" ]
    IF nFrameLimit > 0
        nFrameLimit += Min( nMaxHeader, hbbridgeruntimelimits()[ "stringBytesMax" ] - nFrameLimit )
    ENDIF
    pDecoder := HBBridgeInflateOpen( nFrameLimit )
    IF Empty( pDecoder )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO WHILE .T.
            nWait := ioremaining( aDeadline )
            IF nWait == 0
                EXIT
            ENDIF
            cChunk := Space( hPolicy[ "protheusReadChunkBytes" ] )
            nBytesRead := hb_socketRecv( hSocket, @cChunk, hb_BLen( cChunk ), 0, nWait )
            IF nBytesRead <= 0 .OR. nBytesRead > hbbridgeruntimelimits()[ "stringBytesMax" ] - nWireBytes
                EXIT
            ENDIF
            nWireBytes += nBytesRead
            IF overbudget( nWireBytes, hPolicy[ "protheusMaxWireBytes" ] )
                EXIT
            ENDIF
            aDecoded := HBBridgeInflateFeed( pDecoder, hb_BLeft( cChunk, nBytesRead ) )
            IF aDecoded[ 1 ] < 0 .OR. aDecoded[ 3 ] != nBytesRead
                EXIT
            ENDIF
            FOR EACH cPart IN aDecoded[ 2 ]
                cBuffer += cPart
            NEXT
            IF nHeaderEnd == 0
                nHeaderEnd := hbbridgeparseheader( cBuffer, @nPayloadBytes, hPolicy[ "protheusMaxPayloadBytes" ] )
            ENDIF
            IF nHeaderEnd < 0 .OR. ioremaining( aDeadline ) == 0
                EXIT
            ENDIF
            IF nHeaderEnd > 0 .AND. hb_BLen( cBuffer ) - nHeaderEnd > nPayloadBytes
                EXIT
            ENDIF
            IF aDecoded[ 1 ] == 1
                lComplete := .T.
                EXIT
            ENDIF
        ENDDO
    RECOVER
        lComplete := .F.
    ALWAYS
        HBBridgeInflateClose( pDecoder )
    END SEQUENCE
    IF lComplete .AND. ioremaining( aDeadline ) != 0
        RETURN hbbridgeparseframe( cBuffer, @cPayload, hPolicy[ "protheusMaxPayloadBytes" ] )
    ENDIF

RETURN .F.

/* 0=incomplete, -1=invalid, positive=header bytes including LF. */
FUNCTION hbbridgeparseheader( cFrame, nPayloadBytes, nMaximum )

    LOCAL cPrefix := HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|", cSize, nIndex, cDigit
    LOCAL nHeaderEnd, nPrefixSize := hb_BLen( cPrefix ), nCompare, nRuntimeMax
    LOCAL cRuntimeMax

    nPayloadBytes := 0
    hb_default( @nMaximum, 0 )
    IF ! HBBridgeIntegerValid( nMaximum, hbbridgeruntimelimits()[ "stringBytesMax" ] )
        RETURN -1
    ENDIF
    IF ! HB_ISSTRING( cFrame )
        RETURN -1
    ENDIF
    nCompare := Min( hb_BLen( cFrame ), nPrefixSize )
    IF ! ( hb_BLeft( cFrame, nCompare ) == hb_BLeft( cPrefix, nCompare ) )
        RETURN -1
    ENDIF
    nHeaderEnd := hb_BAt( hb_BChar( 10 ), cFrame )
    IF nHeaderEnd == 0
        RETURN iif( hb_BLen( cFrame ) < headersizemaximum(), 0, -1 )
    ENDIF
    IF nHeaderEnd <= nPrefixSize + 1 .OR. nHeaderEnd > headersizemaximum()
        RETURN -1
    ENDIF
    cSize := hb_BSubStr( cFrame, nPrefixSize + 1, nHeaderEnd - nPrefixSize - 1 )
    IF hb_BLeft( cSize, 1 ) == "0"
        RETURN -1
    ENDIF
    FOR nIndex := 1 TO hb_BLen( cSize )
        cDigit := hb_BSubStr( cSize, nIndex, 1 )
        IF ! ( cDigit $ "0123456789" )
            RETURN -1
        ENDIF
    NEXT
    nRuntimeMax := hbbridgeruntimelimits()[ "stringBytesMax" ] - nHeaderEnd
    cRuntimeMax := hb_ntos( nRuntimeMax )
    IF hb_BLen( cSize ) > hb_BLen( cRuntimeMax )
        RETURN -1
    ENDIF
    IF hb_BLen( cSize ) == hb_BLen( cRuntimeMax ) .AND. cSize > cRuntimeMax
        RETURN -1
    ENDIF
    nPayloadBytes := Val( cSize )
    IF overbudget( nPayloadBytes, nMaximum )
        RETURN -1
    ENDIF

RETURN nHeaderEnd

FUNCTION hbbridgeparseframe( cFrame, cPayload, nMaximum )

    LOCAL nPayloadBytes, nHeaderEnd := hbbridgeparseheader( cFrame, @nPayloadBytes, nMaximum )

    cPayload := ""
    IF nHeaderEnd <= 0
        RETURN .F.
    ENDIF
    IF hb_BLen( cFrame ) - nHeaderEnd != nPayloadBytes
        RETURN .F.
    ENDIF
    IF ! ( hb_BSubStr( cFrame, hb_BLen( HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" ) + 1, ;
        nHeaderEnd - hb_BLen( HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" ) - 1 ) == ;
        hb_ntos( hb_BLen( cFrame ) - nHeaderEnd ) )
        RETURN .F.
    ENDIF
    cPayload := hb_BSubStr( cFrame, nHeaderEnd + 1 )

RETURN .T.

FUNCTION sendresponse( hSocket, cPayload as character, hOptions )

    LOCAL hPolicy := hbbridgeprotheuspolicy( hOptions ), pEncoder, cHeader, aEncoded
    LOCAL nOffset := 1, nBytes, nWireBytes := 0, aDeadline, lSent := .F.

    IF hPolicy == NIL .OR. ! HB_ISSTRING( cPayload )
        RETURN .F.
    ENDIF
    IF hb_BLen( cPayload ) == 0 .OR. overbudget( hb_BLen( cPayload ), hPolicy[ "protheusMaxPayloadBytes" ] )
        RETURN .F.
    ENDIF
    aDeadline := iodeadline( hPolicy[ "protheusTimeoutMs" ] )
    cHeader := HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" + hb_ntos( hb_BLen( cPayload ) ) + hb_BChar( 10 )
    IF hb_BLen( cPayload ) > hbbridgeruntimelimits()[ "stringBytesMax" ] - hb_BLen( cHeader )
        RETURN .F.
    ENDIF
    pEncoder := HBBridgeDeflateOpen()
    IF Empty( pEncoder )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        aEncoded := HBBridgeDeflateFeed( pEncoder, cHeader, .F. )
        IF aEncoded[ 1 ] == 0 .AND. aEncoded[ 3 ] == hb_BLen( cHeader ) .AND. ;
            sendchunks( hSocket, aEncoded[ 2 ], hPolicy, aDeadline, @nWireBytes )
            DO WHILE nOffset <= hb_BLen( cPayload ) .AND. ioremaining( aDeadline ) != 0
                nBytes := Min( hPolicy[ "protheusReadChunkBytes" ], hb_BLen( cPayload ) - nOffset + 1 )
                aEncoded := HBBridgeDeflateFeed( pEncoder, hb_BSubStr( cPayload, nOffset, nBytes ), ;
                    nOffset + nBytes > hb_BLen( cPayload ) )
                IF aEncoded[ 1 ] < 0 .OR. aEncoded[ 3 ] != nBytes
                    EXIT
                ENDIF
                IF ! sendchunks( hSocket, aEncoded[ 2 ], hPolicy, aDeadline, @nWireBytes )
                    EXIT
                ENDIF
                nOffset += nBytes
                lSent := aEncoded[ 1 ] == 1 .AND. nOffset > hb_BLen( cPayload )
            ENDDO
        ENDIF
    RECOVER
        lSent := .F.
    ALWAYS
        HBBridgeDeflateClose( pEncoder )
    END SEQUENCE

RETURN lSent .AND. ioremaining( aDeadline ) != 0

STATIC FUNCTION sendchunks( hSocket, aChunks, hPolicy, aDeadline, nWireBytes )

    LOCAL cChunk, nOffset, nBytes, nWait, nChunkSize

    FOR EACH cChunk IN aChunks
        nOffset := 1
        DO WHILE nOffset <= hb_BLen( cChunk )
            nWait := ioremaining( aDeadline )
            IF nWait == 0
                RETURN .F.
            ENDIF
            nChunkSize := Min( hPolicy[ "protheusReadChunkBytes" ], hb_BLen( cChunk ) - nOffset + 1 )
            IF nChunkSize > hbbridgeruntimelimits()[ "stringBytesMax" ] - nWireBytes .OR. ;
                overbudget( nWireBytes + nChunkSize, hPolicy[ "protheusMaxWireBytes" ] )
                RETURN .F.
            ENDIF
            nBytes := hb_socketSend( hSocket, hb_BSubStr( cChunk, nOffset, nChunkSize ), NIL, 0, nWait )
            IF nBytes <= 0 .OR. nBytes > nChunkSize
                RETURN .F.
            ENDIF
            nOffset += nBytes
            nWireBytes += nBytes
        ENDDO
    NEXT

RETURN .T.

STATIC FUNCTION headersizemaximum()
RETURN hb_BLen( HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" ) + ;
    hb_BLen( hb_ntos( hbbridgeruntimelimits()[ "stringBytesMax" ] ) ) + 1

STATIC FUNCTION overbudget( nBytes, nMaximum )
RETURN nMaximum > 0 .AND. nBytes > nMaximum

STATIC FUNCTION iodeadline( nTimeoutMs )
RETURN { hbbridgemonotonicms(), nTimeoutMs }

STATIC FUNCTION ioremaining( aDeadline )
    IF aDeadline[ 2 ] == 0
        RETURN -1
    ENDIF
RETURN Max( 0, aDeadline[ 2 ] - ( hbbridgemonotonicms() - aDeadline[ 1 ] ) )
