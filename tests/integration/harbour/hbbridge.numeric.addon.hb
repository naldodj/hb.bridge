/* Released to Public Domain. */
/* Deterministic numeric ABI fixture; no SQL, clock or pacing dependency. */
FUNCTION Main( cJSON )

    LOCAL hParams, hResult

    IF ! HBBridgeJSONComplete( cJSON, HBBridgeJSONDecode( cJSON, @hParams ) ) .OR. ! HB_ISHASH( hParams )
        RETURN HBBridgeJSONEncode( { "success" => .F., "code" => "INVALID_PARAMS" } )
    ENDIF
    hResult := { "success" => .T., "received" => hParams, "totalMs" => 1, ;
        "completedIterations" => 3, "avgMs" => 1 / 3, "small" => 0.00000000000000000001, ;
        "large" => 9007199254740991, "decimalText" => "12345678901234567890.123456789" }

RETURN HBBridgeJSONEncode( hResult ) + hb_HGetDef( hParams, "suffix", "" )
