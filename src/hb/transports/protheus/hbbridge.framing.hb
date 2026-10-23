/* Released to Public Domain. */
#include "hbbridge.h"

/* Copy only transport settings; zero budgets do not impose application caps. */
FUNCTION HBBridgeProtheusPolicy( hOptions )

    LOCAL cKey

    LOCAL hPolicy := { "protheusMaxPayloadBytes" => 0, "protheusMaxWireBytes" => 0, ;
        "protheusReadChunkBytes" => HBBRIDGE_IO_CHUNK_DEFAULT_BYTES, ;
        "protheusTimeoutMs" => HBBRIDGE_IO_TIMEOUT_DEFAULT_MS }
    LOCAL hRuntime := HBBridgeRuntimeLimits()

    LOCAL nValue, nMaximum

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

FUNCTION ReceiveRequest( hSocket, cPayload as character, hOptions )

    LOCAL aDecoded, aDeadline

    LOCAL cBuffer, cChunk, cPart

    LOCAL hPolicy

    LOCAL lComplete

    LOCAL nBytesRead, nWireBytes, nWait, nHeaderEnd, nPayloadBytes, nFrameLimit, nMaxHeader, nReadChunkBytes, nStringBytesMax

    LOCAL pDecoder

    hPolicy := HBBridgeProtheusPolicy( hOptions )
    cBuffer := ""
    nWireBytes := 0
    nHeaderEnd := 0
    nPayloadBytes := 0
    nMaxHeader := HeaderSizeMaximum()
    lComplete := .F.

    cPayload := ""
    IF hPolicy == NIL
        RETURN .F.
    ENDIF
    nReadChunkBytes := hPolicy[ "protheusReadChunkBytes" ]
    nStringBytesMax := HBBridgeRuntimeLimits()[ "stringBytesMax" ]
    aDeadline := IODeadline( hPolicy[ "protheusTimeoutMs" ] )
    nFrameLimit := hPolicy[ "protheusMaxPayloadBytes" ]
    IF nFrameLimit > 0
        nFrameLimit += Min( nMaxHeader, nStringBytesMax - nFrameLimit )
    ENDIF
    pDecoder := HBBridgeInflateOpen( nFrameLimit )
    IF Empty( pDecoder )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO WHILE .T.
            nWait := IORemaining( aDeadline )
            IF nWait == 0
                EXIT
            ENDIF
            cChunk := Space( nReadChunkBytes )
            nBytesRead := hb_socketRecv( hSocket, @cChunk, nReadChunkBytes, 0, nWait )
            IF nBytesRead <= 0 .OR. nBytesRead > nStringBytesMax - nWireBytes
                EXIT
            ENDIF
            nWireBytes += nBytesRead
            IF OverBudget( nWireBytes, hPolicy[ "protheusMaxWireBytes" ] )
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
                nHeaderEnd := HBBridgeParseHeader( cBuffer, @nPayloadBytes, hPolicy[ "protheusMaxPayloadBytes" ] )
            ENDIF
            IF nHeaderEnd < 0 .OR. IORemaining( aDeadline ) == 0
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
    IF lComplete .AND. IORemaining( aDeadline ) != 0
        RETURN HBBridgeParseFrame( cBuffer, @cPayload, hPolicy[ "protheusMaxPayloadBytes" ] )
    ENDIF

RETURN .F.

/* 0=incomplete, -1=invalid, positive=header bytes including LF. */
FUNCTION HBBridgeParseHeader( cFrame, nPayloadBytes, nMaximum )

    LOCAL cPrefix := HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|", cSize, cDigit, cRuntimeMax

    LOCAL nIndex, nHeaderEnd, nPrefixSize := hb_BLen( cPrefix ), nCompare, nRuntimeMax, nSizeLength

    nPayloadBytes := 0
    hb_default( @nMaximum, 0 )
    IF ! HBBridgeIntegerValid( nMaximum, HBBridgeRuntimeLimits()[ "stringBytesMax" ] )
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
        RETURN iif( hb_BLen( cFrame ) < HeaderSizeMaximum(), 0, -1 )
    ENDIF
    IF nHeaderEnd <= nPrefixSize + 1 .OR. nHeaderEnd > HeaderSizeMaximum()
        RETURN -1
    ENDIF
    cSize := hb_BSubStr( cFrame, nPrefixSize + 1, nHeaderEnd - nPrefixSize - 1 )
    IF hb_BLeft( cSize, 1 ) == "0"
        RETURN -1
    ENDIF
    nSizeLength := hb_BLen( cSize )
    FOR nIndex := 1 TO nSizeLength
        cDigit := hb_BSubStr( cSize, nIndex, 1 )
        IF ! ( cDigit $ "0123456789" )
            RETURN -1
        ENDIF
    NEXT
    nRuntimeMax := HBBridgeRuntimeLimits()[ "stringBytesMax" ] - nHeaderEnd
    cRuntimeMax := hb_ntos( nRuntimeMax )
    IF hb_BLen( cSize ) > hb_BLen( cRuntimeMax )
        RETURN -1
    ENDIF
    IF hb_BLen( cSize ) == hb_BLen( cRuntimeMax ) .AND. cSize > cRuntimeMax
        RETURN -1
    ENDIF
    nPayloadBytes := Val( cSize )
    IF OverBudget( nPayloadBytes, nMaximum )
        RETURN -1
    ENDIF

RETURN nHeaderEnd

FUNCTION HBBridgeParseFrame( cFrame, cPayload, nMaximum )

    LOCAL nPayloadBytes, nHeaderEnd := HBBridgeParseHeader( cFrame, @nPayloadBytes, nMaximum )

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

FUNCTION SendResponse( hSocket, cPayload as character, hOptions, hDiagnostics )

    LOCAL aEncoded, aDeadline

    LOCAL cHeader

    LOCAL hPolicy

    LOCAL lSent

    LOCAL nOffset, nBytes, nWireBytes, nPayloadBytes, nReadChunkBytes, nStarted

    LOCAL pEncoder

    hPolicy := HBBridgeProtheusPolicy( hOptions )
    nOffset := 1
    nWireBytes := 0
    lSent := .F.
    nStarted := HBBridgeMonotonicMs()
    hb_default( @hDiagnostics, {=>} )
    hDiagnostics[ "failureCategory" ] := "INVALID_RESPONSE"
    hDiagnostics[ "socketError" ] := 0
    hDiagnostics[ "wireBytes" ] := 0
    hDiagnostics[ "payloadBytes" ] := 0

    IF hPolicy == NIL .OR. ! HB_ISSTRING( cPayload )
        RETURN .F.
    ENDIF
    nPayloadBytes := hb_BLen( cPayload )
    hDiagnostics[ "payloadBytes" ] := nPayloadBytes
    hDiagnostics[ "ioTimeoutMs" ] := hPolicy[ "protheusTimeoutMs" ]
    hDiagnostics[ "failureCategory" ] := "PAYLOAD_BUDGET_EXCEEDED"
    nReadChunkBytes := hPolicy[ "protheusReadChunkBytes" ]
    IF nPayloadBytes == 0 .OR. OverBudget( nPayloadBytes, hPolicy[ "protheusMaxPayloadBytes" ] )
        RETURN .F.
    ENDIF
    aDeadline := IODeadline( hPolicy[ "protheusTimeoutMs" ] )
    cHeader := HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" + hb_ntos( nPayloadBytes ) + hb_BChar( 10 )
    IF nPayloadBytes > HBBridgeRuntimeLimits()[ "stringBytesMax" ] - hb_BLen( cHeader )
        RETURN .F.
    ENDIF
    pEncoder := HBBridgeDeflateOpen()
    hDiagnostics[ "failureCategory" ] := "COMPRESSION_FAILED"
    IF Empty( pEncoder )
        RETURN .F.
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        aEncoded := HBBridgeDeflateFeed( pEncoder, cHeader, .F. )
        IF aEncoded[ 1 ] == 0 .AND. aEncoded[ 3 ] == hb_BLen( cHeader ) .AND. ;
            SendChunks( hSocket, aEncoded[ 2 ], hPolicy, aDeadline, @nWireBytes, hDiagnostics )
            DO WHILE nOffset <= nPayloadBytes .AND. IORemaining( aDeadline ) != 0
                nBytes := Min( nReadChunkBytes, nPayloadBytes - nOffset + 1 )
                aEncoded := HBBridgeDeflateFeed( pEncoder, hb_BSubStr( cPayload, nOffset, nBytes ), ;
                    nOffset + nBytes > nPayloadBytes )
                IF aEncoded[ 1 ] < 0 .OR. aEncoded[ 3 ] != nBytes
                    EXIT
                ENDIF
                IF ! SendChunks( hSocket, aEncoded[ 2 ], hPolicy, aDeadline, @nWireBytes, hDiagnostics )
                    EXIT
                ENDIF
                nOffset += nBytes
                lSent := aEncoded[ 1 ] == 1 .AND. nOffset > nPayloadBytes
            ENDDO
        ENDIF
    RECOVER
        lSent := .F.
    ALWAYS
        HBBridgeDeflateClose( pEncoder )
    END SEQUENCE
    hDiagnostics[ "wireBytes" ] := nWireBytes
    hDiagnostics[ "elapsedMs" ] := HBBridgeMonotonicMs() - nStarted
    IF IORemaining( aDeadline ) == 0
        hDiagnostics[ "failureCategory" ] := "SEND_TIMEOUT"
    ELSEIF lSent
        hDiagnostics[ "failureCategory" ] := ""
    ENDIF

RETURN lSent .AND. IORemaining( aDeadline ) != 0

STATIC FUNCTION SendChunks( hSocket, aChunks, hPolicy, aDeadline, nWireBytes, hDiagnostics )

    LOCAL cChunk

    LOCAL nOffset, nBytes, nWait, nChunkSize, nChunkBytes, nReadChunkBytes, nStringBytesMax

    nReadChunkBytes := hPolicy[ "protheusReadChunkBytes" ]
    nStringBytesMax := HBBridgeRuntimeLimits()[ "stringBytesMax" ]
    FOR EACH cChunk IN aChunks
        nChunkBytes := hb_BLen( cChunk )
        nOffset := 1
        DO WHILE nOffset <= nChunkBytes
            nWait := IORemaining( aDeadline )
            IF nWait == 0
                hDiagnostics[ "failureCategory" ] := "SEND_TIMEOUT"
                RETURN .F.
            ENDIF
            nChunkSize := Min( nReadChunkBytes, nChunkBytes - nOffset + 1 )
            IF nChunkSize > nStringBytesMax - nWireBytes .OR. ;
                OverBudget( nWireBytes + nChunkSize, hPolicy[ "protheusMaxWireBytes" ] )
                hDiagnostics[ "failureCategory" ] := "WIRE_BUDGET_EXCEEDED"
                RETURN .F.
            ENDIF
            nBytes := hb_socketSend( hSocket, hb_BSubStr( cChunk, nOffset, nChunkSize ), NIL, 0, nWait )
            IF nBytes <= 0 .OR. nBytes > nChunkSize
                hDiagnostics[ "failureCategory" ] := "SOCKET_SEND_FAILED"
                hDiagnostics[ "socketError" ] := hb_socketGetError()
                RETURN .F.
            ENDIF
            nOffset += nBytes
            nWireBytes += nBytes
        ENDDO
    NEXT

RETURN .T.

STATIC FUNCTION HeaderSizeMaximum()
RETURN hb_BLen( HBBRIDGE_PROTOCOL_SIGNATURE + "|JSON|" ) + ;
    hb_BLen( hb_ntos( HBBridgeRuntimeLimits()[ "stringBytesMax" ] ) ) + 1

STATIC FUNCTION OverBudget( nBytes, nMaximum )
RETURN nMaximum > 0 .AND. nBytes > nMaximum

STATIC FUNCTION IODeadline( nTimeoutMs )
RETURN { HBBridgeMonotonicMs(), nTimeoutMs }

STATIC FUNCTION IORemaining( aDeadline )
    IF aDeadline[ 2 ] == 0
        RETURN -1
    ENDIF
RETURN Max( 0, aDeadline[ 2 ] - ( HBBridgeMonotonicMs() - aDeadline[ 1 ] ) )
