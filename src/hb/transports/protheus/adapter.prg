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

/* Compatibility adapter for HBBRIDGE/1 and HBS1. */
FUNCTION DispatcherRequest( cJsonStr, hRegistry, hContext )

   LOCAL hRequest, cService, xParams := NIL, nVersion := 1, nConsumed

   nConsumed := hb_jsonDecode( cJsonStr, @hRequest )
   IF nConsumed == 0 .OR. ! Empty( AllTrim( SubStr( cJsonStr, nConsumed + 1 ) ) ) .OR. ;
      ! HB_ISHASH( hRequest )
      RETURN hb_jsonEncode( HBBridgeError( "INVALID_JSON", "Payload JSON invalido" ) )
   ENDIF
   IF ! hb_HHasKey( hRequest, "service" )
      RETURN hb_jsonEncode( HBBridgeError( "INVALID_JSON", "Payload JSON invalido" ) )
   ENDIF
   cService := hRequest[ "service" ]
   IF ! HB_ISSTRING( cService )
      RETURN hb_jsonEncode( HBBridgeError( "INVALID_SERVICE", "Servico invalido" ) )
   ENDIF
   IF hb_HHasKey( hRequest, "params" )
      xParams := hRequest[ "params" ]
   ELSEIF cService == "Echo" .OR. Left( cService, 6 ) == "ADDON."
      RETURN hb_jsonEncode( HBBridgeError( "INVALID_PARAMS", "Parametros ausentes" ) )
   ENDIF
   IF hb_HHasKey( hRequest, "version" )
      nVersion := hRequest[ "version" ]
   ENDIF
   IF Left( cService, 6 ) == "ADDON." .AND. cService != "ADDON.Execute"
      xParams := { "module" => SubStr( cService, 7 ), "params" => xParams }
      cService := "ADDON.Execute"
   ENDIF
   IF hRegistry == NIL
      hRegistry := HBBridgeBuiltinRegistry()
   ENDIF
   IF hContext == NIL
      hContext := HBBridgeContext( "protheus" )
   ENDIF

RETURN hb_jsonEncode( HBBridgeDispatch( hRegistry, cService, xParams, hContext, nVersion ) )
