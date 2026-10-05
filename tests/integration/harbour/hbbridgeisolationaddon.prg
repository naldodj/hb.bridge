// Each separately loaded HRB must have its own static storage, even concurrently.
FUNCTION mtaddonisolation( cJsonParams )

    STATIC nCounter := 0
    LOCAL hParams

    hb_jsonDecode( cJsonParams, @hParams )
    nCounter++
    hb_idleSleep( 0.2 )

RETURN hb_jsonEncode( { "success" => .T., "id" => hParams[ "id" ], "counter" => nCounter } )
