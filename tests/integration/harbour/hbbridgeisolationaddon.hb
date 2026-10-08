// Simultaneously loaded HRBs own independent static storage. Harbour may retain
// its values when an unloaded module is reused by a later execution.
FUNCTION MTAddonIsolation( cJsonParams )

    STATIC nCounter := 0
    STATIC nOwner := NIL
    LOCAL hParams, nCounterBefore, lAllActive := .T.

    hb_jsonDecode( cJsonParams, @hParams )
    nCounterBefore := nCounter
    nCounter++
    // Set the STATIC owner for this execution, then validate it only after all
    // HRBs reach the host barrier. Shared statics would overwrite other owners.
    nOwner := hParams[ "id" ]
    IF hb_HGetDef( hParams, "synchronize", .F. )
        lAllActive := MTAddonBarrier( hParams[ "id" ] )
    ENDIF
    hb_idleSleep( 0.2 )

RETURN hb_jsonEncode( { "success" => .T., "id" => hParams[ "id" ], ;
    "owner" => nOwner, "counterBefore" => nCounterBefore, ;
    "counter" => nCounter, "allActive" => lAllActive } )
