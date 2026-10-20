/* Released to Public Domain. */
REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE HBBridgeJSONTests( nFailures, nChecks )

    LOCAL cPrevious := hb_cdpSelect(), hCases, cBits, cJSON, xValue, xDecoded
    LOCAL hResult, cInvalid, nConsumed, hCycle := {=>}, cUnicode := hb_HexToStr( "C3A7E6BCA2F09F9880" )

    hb_cdpSelect( "UTF8EX" )
    hCases := { "fraction" => "405EDD3A92A30553", "negative" => "C05EDD3A92A30553", ;
        "tenth" => "3FB999999999999A", "digits" => "3FF3C0CA428C59FB", ;
        "small" => "3BC79CA10C924223", "large" => "4415AF1D78B58C40", ;
        "minNormal" => "0010000000000000", "minSubnormal" => "0000000000000001", ;
        "maxFinite" => "7FEFFFFFFFFFFFFF", "negativeZero" => "8000000000000000" }
    FOR EACH cBits IN hCases
        xValue := HBBridgeJSONTestDouble( cBits )
        cJSON := HBBridgeJSONEncode( { "value" => xValue } )
        nConsumed := HBBridgeJSONDecode( cJSON, @xDecoded )
        M1Assert( HBBridgeJSONComplete( cJSON, nConsumed ) .AND. ;
            HBBridgeJSONTestSame( xValue, xDecoded[ "value" ] ), ;
            "D03 binary64 round trip " + cBits:__enumKey(), @nFailures, @nChecks )
    NEXT
    xValue := HBBridgeJSONTestDouble( "405EDD3A92A30553" )
    M1Assert( ! ( HBBridgeJSONEncode( xValue ) == "123" ), ;
        "D03 zero decimal metadata does not discard FLOAT fraction", @nFailures, @nChecks )
    M1Assert( HBBridgeJSONEncode( 12.50 ) == "12.50", ;
        "D03 exact existing DECIMAL scale is retained", @nFailures, @nChecks )
    FOR EACH cJSON IN { "9223372036854775807", "-9223372036854775808", "9007199254740993" }
        nConsumed := HBBridgeJSONDecode( cJSON, @xValue )
        M1Assert( HBBridgeJSONComplete( cJSON, nConsumed ) .AND. HBBridgeJSONEncode( xValue ) == cJSON, ;
            "D03 native signed integer precision " + cJSON, @nFailures, @nChecks )
    NEXT
    FOR EACH cInvalid IN { "", "01", "+1", "1.", "1e", "1e+", "1e999", "1e-999", ;
        "9223372036854775808", "[1,]", '{"x":1,}', "[true false]", '"bad\x"', ;
        '"bad' + Chr( 0 ) + '"', "true" + Chr( 0 ), "null trailing" }
        nConsumed := HBBridgeJSONDecode( cInvalid, @xValue )
        M1Assert( ! HBBridgeJSONComplete( cInvalid, nConsumed ), ;
            "D03 rejects malformed/range JSON " + hb_StrToHex( cInvalid ), @nFailures, @nChecks )
    NEXT
    M1Assert( HBBridgeJSONEncode( HBBridgeJSONTestDouble( "7FF0000000000000" ) ) == NIL .AND. ;
        HBBridgeJSONEncode( HBBridgeJSONTestDouble( "7FF8000000000000" ) ) == NIL, ;
        "D03 nonfinite numeric results fail explicitly", @nFailures, @nChecks )
    cJSON := HBBridgeJSONEncode( { "unicode" => cUnicode, "nul" => "A" + Chr( 0 ) + "B", ;
        "empty" => "", "null" => NIL, "values" => { .T., .F., SToD( "20261019" ) } } )
    nConsumed := HBBridgeJSONDecode( cJSON, @hResult )
    M1Assert( HBBridgeJSONComplete( cJSON, nConsumed ) .AND. hResult[ "unicode" ] == cUnicode .AND. ;
        hResult[ "nul" ] == "A" + Chr( 0 ) + "B" .AND. hResult[ "empty" ] == "" .AND. ;
        hResult[ "null" ] == NIL .AND. hResult[ "values" ][ 1 ] .AND. ! hResult[ "values" ][ 2 ], ;
        "D03 text/null/logical/native date behavior survives nested JSON", @nFailures, @nChecks )
    hCycle[ "self" ] := hCycle
    M1Assert( HBBridgeJSONEncode( hCycle ) == '{"self":null}', ;
        "D03 cycles retain native JSON null behavior", @nFailures, @nChecks )
    hCycle[ "self" ] := NIL
    hb_cdpSelect( "EN" )
    cJSON := DispatcherRequest( '{"service":"Echo","params":{"text":"' + cUnicode + '"}}' )
    M1Assert( hb_cdpSelect() == "EN", "D03 dispatcher restores caller codepage on success", @nFailures, @nChecks )
    HBBridgeJSONDecode( cJSON, @hResult )
    M1Assert( hResult[ "success" ] .AND. hResult[ "params" ][ "text" ] == cUnicode, ;
        "D03 dispatcher executes Unicode under UTF8EX from EN caller", @nFailures, @nChecks )
    cJSON := DispatcherRequest( '{"service":"Echo","params":{"text":"\ud83d\ude00"}}' )
    HBBridgeJSONDecode( cJSON, @hResult )
    M1Assert( hResult[ "params" ][ "text" ] == hb_HexToStr( "F09F9880" ), ;
        "D03 shared dispatcher normalizes Unicode surrogate pairs", @nFailures, @nChecks )
    FOR EACH cInvalid IN { '{"service":"Echo","params":"' + Chr( 255 ) + '"}', ;
        '{"service":"Health","params":"\ud800"}', '{"service":"Health"}' + Chr( 0 ) }
        cJSON := DispatcherRequest( cInvalid )
        HBBridgeJSONDecode( cJSON, @hResult )
        M1Assert( ! hResult[ "success" ] .AND. hb_cdpSelect() == "EN", ;
            "D03 rejects invalid text and restores caller codepage", @nFailures, @nChecks )
    NEXT
    hb_cdpSelect( cPrevious )

RETURN
