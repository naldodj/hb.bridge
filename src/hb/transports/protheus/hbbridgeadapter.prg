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
FUNCTION dispatcherrequest( cJsonStr, hRegistry, hContext )

    LOCAL hRequest, cService, xParams := NIL, nVersion := 1, nConsumed

    nConsumed := hb_jsonDecode( cJsonStr, @hRequest )
    IF nConsumed == 0 .OR. ! Empty( AllTrim( SubStr( cJsonStr, nConsumed + 1 ) ) ) .OR. ;
        ! HB_ISHASH( hRequest )
        RETURN hb_jsonEncode( hbbridgeerror( "INVALID_JSON", "Payload JSON invalido" ) )
    ENDIF
    IF ! hb_HHasKey( hRequest, "service" )
        RETURN hb_jsonEncode( hbbridgeerror( "INVALID_JSON", "Payload JSON invalido" ) )
    ENDIF
    cService := hRequest[ "service" ]
    IF ! HB_ISSTRING( cService )
        RETURN hb_jsonEncode( hbbridgeerror( "INVALID_SERVICE", "Servico invalido" ) )
    ENDIF
    IF hb_HHasKey( hRequest, "params" )
        xParams := hRequest[ "params" ]
    ELSEIF cService == "Echo" .OR. cService == "ADDON.Execute"
        RETURN hb_jsonEncode( hbbridgeerror( "INVALID_PARAMS", "Parametros ausentes" ) )
    ENDIF
    IF hb_HHasKey( hRequest, "version" )
        nVersion := hRequest[ "version" ]
    ENDIF
    IF hRegistry == NIL
        hRegistry := hbbridgebuiltinregistry()
    ENDIF
    IF hContext == NIL
        hContext := hbbridgecontext( "protheus" )
    ENDIF

RETURN hb_jsonEncode( hbbridgedispatch( hRegistry, cService, xParams, hContext, nVersion ) )
