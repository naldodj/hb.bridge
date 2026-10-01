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
FUNCTION DispatcherRequest( cJsonStr )
   LOCAL oJson, cService
   hb_jsonDecode( cJsonStr, @oJson )
   IF ! HB_ISHASH( oJson )
      RETURN '{"success": false, "error": "Payload JSON invalido"}'
   ENDIF
   IF ! HB_HHasKey( oJson, "service" )
      RETURN '{"success": false, "error": "Payload JSON invalido"}'
   ENDIF
   cService := oJson["service"]
   IF ! HB_ISSTRING( cService )
      RETURN '{"success": false, "error": "Servico invalido"}'
   ENDIF
   IF ( Left( cService, 6 ) == "ADDON." .OR. cService == "Echo" ) .AND. ;
      ! HB_HHasKey( oJson, "params" )
      RETURN '{"success": false, "error": "Parametros ausentes"}'
   ENDIF
   IF Left( cService, 6 ) == "ADDON."
      RETURN HBBridgeServiceAddon( SubStr( cService, 7 ), oJson["params"] )
   ELSEIF cService == "Health"
      RETURN HBBridgeServiceHealth( cJsonStr )
   ELSEIF cService == "Echo"
      RETURN HBBridgeServiceEcho( oJson["params"] )
   ELSE
      RETURN '{"success": false, "error": "Servico nao suportado"}'
   ENDIF
RETURN '{"success": false, "error": "Despacho sem resposta"}'
