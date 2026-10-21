/* Released to Public Domain. */

/* JSON text is UTF-8 independently of the caller's local presentation codepage. */
FUNCTION HBBridgeWireEncode( xValue )

    LOCAL cJSON := HBBridgeJSONEncode( xValue )

    IF ! HB_ISSTRING( cJSON )
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_NUMBER_RESULT", ;
            "JSON result contains an unsupported numeric value." ) )
    ENDIF
    IF ! HBBridgeUTF8Valid( cJSON )
        RETURN HBBridgeJSONEncode( HBBridgeError( "INVALID_UTF8_RESULT", ;
            "Service result must use valid UTF-8 text." ) )
    ENDIF

RETURN cJSON

FUNCTION HBBridgeJSONComplete( cJSON, nConsumed )

    LOCAL nByte, nLength

    IF nConsumed < 1
        RETURN .F.
    ENDIF
    nLength := hb_BLen( cJSON )
    FOR nByte := nConsumed + 1 TO nLength
        IF ! ( Asc( hb_BSubStr( cJSON, nByte, 1 ) ) == 32 .OR. ;
            Asc( hb_BSubStr( cJSON, nByte, 1 ) ) == 9 .OR. ;
            Asc( hb_BSubStr( cJSON, nByte, 1 ) ) == 10 .OR. ;
            Asc( hb_BSubStr( cJSON, nByte, 1 ) ) == 13 )
            RETURN .F.
        ENDIF
    NEXT

RETURN .T.

/* Version 1 has no binary JSON tag/decoder. Preserve native NETIO bytes;
 * JSON callers must explicitly project binary as hex/base64 text in SQL.
 * Reject even UTF-8-looking binary instead of assigning it text semantics.
 */
FUNCTION HBBridgeJSONServiceResult( cService, hResult )

    LOCAL cType

    LOCAL hField

    LOCAL nFlags

    IF cService == "RPCRDD.Query" .AND. HB_ISHASH( hResult ) .AND. ;
        hb_HGetDef( hResult, "success", .F. ) .AND. ;
        HB_ISHASH( hb_HGetDef( hResult, "header", NIL ) )
        FOR EACH hField IN hResult[ "header" ]
            cType := hb_HGetDef( hField, "type", "" )
            nFlags := At( ":", cType )
            IF nFlags > 0 .AND. "B" $ SubStr( cType, nFlags + 1 )
                RETURN HBBridgeError( "BINARY_JSON_UNSUPPORTED", ;
                    "Project binary columns as explicit hex/base64 text for JSON transport." )
            ENDIF
        NEXT
    ENDIF

RETURN hResult
