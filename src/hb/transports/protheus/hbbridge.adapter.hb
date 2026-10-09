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
FUNCTION DispatcherRequest( cJsonStr, hRegistry, hContext )

    LOCAL hRequest, cService, xParams := NIL, nVersion := 1, nConsumed

    nConsumed := hb_jsonDecode( cJsonStr, @hRequest )
    IF nConsumed == 0 .OR. ! Empty( AllTrim( hb_BSubStr( cJsonStr, nConsumed + 1 ) ) ) .OR. ;
        ! HB_ISHASH( hRequest )
        RETURN hb_jsonEncode( HBBridgeError( "INVALID_JSON", "Invalid JSON payload" ) )
    ENDIF
    IF ! hb_HHasKey( hRequest, "service" )
        RETURN hb_jsonEncode( HBBridgeError( "INVALID_JSON", "Invalid JSON payload" ) )
    ENDIF
    cService := hRequest[ "service" ]
    IF ! HB_ISSTRING( cService )
        RETURN hb_jsonEncode( HBBridgeError( "INVALID_SERVICE", "Invalid service" ) )
    ENDIF
    IF hb_HHasKey( hRequest, "params" )
        xParams := hRequest[ "params" ]
    ELSEIF cService == "Echo" .OR. cService == "ADDON.Execute"
        RETURN hb_jsonEncode( HBBridgeError( "INVALID_PARAMS", "Missing parameters" ) )
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

RETURN hb_jsonEncode( HBBridgeDispatch( hRegistry, cService, xParams, hContext, nVersion ) )
