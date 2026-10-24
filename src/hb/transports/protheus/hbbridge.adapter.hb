/*
 _      _         _            _      _
| |__  | |__     | |__   _ __ (_)  __| |  __ _   ___
| '_ \ | '_ \    | '_ \ | '__|| | / _` | / _` | / _ \
| | | || |_) | _ | |_) || |   | || (_| || (_| ||  __/
|_| |_||_.__/ (_)|_.__/ |_|   |_| \__,_| \__, | \___|
                                         |___/
Released to Public Domain.
--------------------------------------------------------------------------------------
*/

/* JSON representation of the shared service contract for Protheus. */
REQUEST HB_CODEPAGE_UTF8EX

FUNCTION DispatcherRequest( cJsonStr, hRegistry, hContext )

    LOCAL cPreviousCodepage := hb_cdpSelect(), cResult

    LOCAL oError

    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        cResult := HBBridgeWireEncode( DispatcherUTF8Result( cJsonStr, hRegistry, hContext ) )
    RECOVER USING oError
        cResult := HBBridgeWireEncode( HBBridgeError( "SERVICE_ERROR", "Service execution failed", oError ) )
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE

RETURN cResult

/* HTTP consumes the native result and serializes once at its own boundary. */
FUNCTION HBBridgeJSONRequestResult( cJsonStr, hRegistry, hContext )

    LOCAL cPreviousCodepage := hb_cdpSelect()

    LOCAL oError

    LOCAL xResult

    BEGIN SEQUENCE WITH __BreakBlock()
        hb_cdpSelect( "UTF8EX" )
        xResult := DispatcherUTF8Result( cJsonStr, hRegistry, hContext )
    RECOVER USING oError
        xResult := HBBridgeError( "SERVICE_ERROR", "Service execution failed", oError )
    ALWAYS
        hb_cdpSelect( cPreviousCodepage )
    END SEQUENCE

RETURN xResult

STATIC FUNCTION DispatcherUTF8Result( cJsonStr, hRegistry, hContext )

    LOCAL cService

    LOCAL hRequest

    LOCAL nVersion, nConsumed

    LOCAL xParams

    xParams := NIL
    nVersion := 1

    IF ! HBBridgeUTF8Valid( cJsonStr )
        RETURN HBBridgeError( "INVALID_UTF8", "JSON must use valid UTF-8." )
    ENDIF
    IF ( cJsonStr := HBBridgeJSONNormalize( cJsonStr ) ) == NIL
        RETURN HBBridgeError( "INVALID_JSON", "Invalid Unicode escape in JSON." )
    ENDIF
    nConsumed := HBBridgeJSONDecode( cJsonStr, @hRequest )
    IF ! HBBridgeJSONComplete( cJsonStr, nConsumed ) .OR. ;
        ! HB_ISHASH( hRequest )
        RETURN HBBridgeError( "INVALID_JSON", "Invalid JSON payload" )
    ENDIF
    IF ! hb_HHasKey( hRequest, "service" )
        RETURN HBBridgeError( "INVALID_JSON", "Invalid JSON payload" )
    ENDIF
    cService := hRequest[ "service" ]
    IF ! HB_ISSTRING( cService )
        RETURN HBBridgeError( "INVALID_SERVICE", "Invalid service" )
    ENDIF
    IF hb_HHasKey( hRequest, "params" )
        xParams := hRequest[ "params" ]
    ELSEIF cService == "Echo" .OR. cService == "ADDON.Execute"
        RETURN HBBridgeError( "INVALID_PARAMS", "Missing parameters" )
    ENDIF
    IF hb_HHasKey( hRequest, "version" )
        nVersion := hRequest[ "version" ]
    ENDIF
    IF hRegistry == NIL
        hRegistry := HBBridgeBuiltinRegistry()
    ENDIF
    IF hContext == NIL
        hContext := HBBridgeContext( "protheus" )
    ENDIF

RETURN HBBridgeJSONServiceResult( cService, ;
    HBBridgeDispatch( hRegistry, cService, xParams, hContext, nVersion ) )
