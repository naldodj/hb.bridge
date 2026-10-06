// addons/examples/hbbridgesampleaddon.prg
FUNCTION Main( cJsonParams )
    LOCAL oParams, oResp := {=>}
    hb_jsonDecode( cJsonParams, @oParams )
    oResp["success"] := .T.
    oResp["addon_msg"] := "Executado via HRB Addon no hbBridge!"
RETURN hb_jsonEncode( oResp )
