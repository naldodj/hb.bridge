/* Released to Public Domain. */

/* Quality weights are integers, independent of SET DECIMALS/FIXED. */
FUNCTION HBBridgeHTTPEncoding( cAccept )

    LOCAL cEntry, cName, cParameters

    LOCAL hWeights := {=>}

    LOCAL nComma, nSemicolon, nQuality

    cAccept := Lower( StrTran( cAccept, Chr( 9 ), " " ) )
    DO WHILE ! Empty( cAccept )
        nComma := At( ",", cAccept )
        IF nComma == 0
            cEntry := AllTrim( cAccept )
            cAccept := ""
        ELSE
            cEntry := AllTrim( Left( cAccept, nComma - 1 ) )
            cAccept := SubStr( cAccept, nComma + 1 )
        ENDIF
        nSemicolon := At( ";", cEntry )
        cName := AllTrim( iif( nSemicolon == 0, cEntry, Left( cEntry, nSemicolon - 1 ) ) )
        IF ! ( cName == "gzip" .OR. cName == "identity" .OR. cName == "*" )
            LOOP
        ENDIF
        nQuality := 1000
        IF nSemicolon > 0
            cParameters := AllTrim( SubStr( cEntry, nSemicolon + 1 ) )
            IF Left( cParameters, 2 ) == "q="
                nQuality := HTTPQuality( AllTrim( SubStr( cParameters, 3 ) ) )
            ELSE
                nQuality := 0
            ENDIF
        ENDIF
        /* Conflicting duplicates use the most restrictive weight. */
        hWeights[ cName ] := Min( hb_HGetDef( hWeights, cName, 1000 ), nQuality )
    ENDDO

RETURN { "gzip" => hb_HGetDef( hWeights, "gzip", hb_HGetDef( hWeights, "*", 0 ) ), ;
    "identity" => hb_HGetDef( hWeights, "identity", ;
        iif( hb_HGetDef( hWeights, "*", 1000 ) == 0, 0, 1000 ) ) }

STATIC FUNCTION HTTPQuality( cQuality )

    LOCAL cLeading := Left( cQuality, 1 ), cDigit

    LOCAL nIndex, nLength := Len( cQuality ), nWeight := 0

    IF nLength < 1 .OR. nLength > 5 .OR. ! ( cLeading $ "01" )
        RETURN 0
    ENDIF
    IF nLength > 1 .AND. SubStr( cQuality, 2, 1 ) != "."
        RETURN 0
    ENDIF
    FOR nIndex := 3 TO nLength
        cDigit := SubStr( cQuality, nIndex, 1 )
        IF ! ( cDigit $ "0123456789" ) .OR. ( cLeading == "1" .AND. cDigit != "0" )
            RETURN 0
        ENDIF
        nWeight := nWeight * 10 + Asc( cDigit ) - 48
    NEXT
    IF cLeading == "1"
        RETURN 1000
    ENDIF

RETURN nWeight * ( 10 ^ Max( 0, 5 - nLength ) )

FUNCTION HBBridgeHTTPContent( cBody, cAccept, hConfig )

    LOCAL cCompressed

    LOCAL hWeights := HBBridgeHTTPEncoding( cAccept )

    LOCAL lGzip := hConfig[ "httpCompression" ] == "auto" .AND. hWeights[ "gzip" ] > 0

    UAddHeader( "Vary", "Accept-Encoding" )
    IF lGzip .AND. Empty( UGetHeader( "Content-Encoding", "" ) ) .AND. ;
        ( hWeights[ "identity" ] == 0 .OR. ;
        ( hWeights[ "gzip" ] >= hWeights[ "identity" ] .AND. ;
        hb_BLen( cBody ) >= hConfig[ "httpCompressionMinBytes" ] ) )
        cCompressed := HTTPGzip( cBody, hConfig[ "httpCompressionLevel" ] )
        IF HB_ISSTRING( cCompressed ) .AND. ! Empty( cCompressed ) .AND. ;
            ( hWeights[ "identity" ] == 0 .OR. hb_BLen( cCompressed ) < hb_BLen( cBody ) )
            UAddHeader( "Content-Encoding", "gzip" )
            RETURN cCompressed
        ENDIF
    ENDIF
    IF hWeights[ "identity" ] == 0
        USetStatusCode( 406 )
        UAddHeader( "Content-Type", "application/json; charset=utf-8" )
        /* No representation is acceptable; an empty 406 cannot violate a coding ban. */
        RETURN ""
    ENDIF

RETURN cBody

/* Reuse the incremental native codec; total input is not narrowed to zlib uInt. */
STATIC FUNCTION HTTPGzip( cBody, nLevel )

    /* The codec's native ABI returns status/output chunks/consumed as arrays. */
    LOCAL aEncoded

    LOCAL cCompressed := "", cPart

    LOCAL nLength := hb_BLen( cBody ), nOffset := 1, nBytes

    LOCAL pEncoder := HBBridgeDeflateOpen( nLevel )

    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO WHILE nOffset <= nLength
            nBytes := Min( 65536, nLength - nOffset + 1 )
            aEncoded := HBBridgeDeflateFeed( pEncoder, hb_BSubStr( cBody, nOffset, nBytes ), ;
                nOffset + nBytes > nLength )
            IF aEncoded[ 1 ] < 0 .OR. aEncoded[ 3 ] != nBytes
                cCompressed := NIL
                EXIT
            ENDIF
            FOR EACH cPart IN aEncoded[ 2 ]
                cCompressed += cPart
            NEXT
            nOffset += nBytes
        ENDDO
        IF nLength == 0 .OR. aEncoded[ 1 ] != 1
            cCompressed := NIL
        ENDIF
    RECOVER
        cCompressed := NIL
    ALWAYS
        HBBridgeDeflateClose( pEncoder )
    END SEQUENCE

RETURN cCompressed
