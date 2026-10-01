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
/* Existing MVP service behavior. The versioned/native service contract is
 * a later milestone; these handlers still return the original JSON payloads.
 */
FUNCTION HBBridgeServiceHealth( cJsonStr )
RETURN ZigEngine_Dispatch( cJsonStr )

FUNCTION HBBridgeServiceEcho( xParams )
RETURN '{"success": true, "service": "Echo", "params": ' + hb_jsonEncode( xParams ) + '}'

FUNCTION HBBridgeServiceAddon( cAddonName, xParams )
RETURN ExecutarAddonHRB( cAddonName, xParams )
