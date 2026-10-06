PROCEDURE M1ServiceTests( nFailures, nChecks )

    LOCAL hRegistry := HBBridgeBuiltinRegistry(), hContext := HBBridgeContext( "test" )
    LOCAL hResult, xBad, aCycle := {}, hSpec, hCustom, aCatalog, cJson

    hResult := HBBridgeDispatch( hRegistry, "Core.Upper", "harbour", hContext )
    M1Assert( hResult[ "result" ] == "HARBOUR", "registered core function", @nFailures, @nChecks )
    FOR EACH xBad IN { "1", 0, 1.5, .T. }
        hResult := HBBridgeDispatch( hRegistry, "Echo", NIL, hContext, xBad )
        M1Assert( hResult[ "code" ] == "INVALID_VERSION", "invalid service version rejected", @nFailures, @nChecks )
    NEXT
    hResult := HBBridgeDispatch( hRegistry, "Echo", NIL, hContext, 2 )
    M1Assert( hResult[ "code" ] == "SERVICE_NOT_FOUND", "unknown service version rejected", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "Admin.Status", NIL, hContext )
    M1Assert( hResult[ "code" ] == "FORBIDDEN", "data context cannot invoke admin service", @nFailures, @nChecks )
    hResult := HBBridgeDispatch( hRegistry, "Core.Upper", 1, hContext )
    M1Assert( hResult[ "code" ] == "INVALID_PARAMS", "signature enforced", @nFailures, @nChecks )
    AAdd( aCycle, aCycle )
    M1Assert( ! HBBridgeValueAllowed( aCycle ) .AND. ! HBBridgeValueAllowed( {|| NIL } ) .AND. ;
        ! HBBridgeValueAllowed( { 1 => "numeric key" } ), "cycles, executable values and nonstring keys rejected", @nFailures, @nChecks )
    ASize( aCycle, 0 )
    hResult := HBBridgeDispatch( hRegistry, "ADDON.Execute", ;
        { "module" => "../outside.hrb", "params" => {=>} }, hContext )
    M1Assert( hResult[ "code" ] == "INVALID_MODULE", "addon traversal rejected", @nFailures, @nChecks )
    aCatalog := HBBridgeCatalog( hRegistry, hContext )
    aCatalog[ 1 ][ "name" ] := "modified"
    M1Assert( HBBridgeCatalog( hRegistry, hContext )[ 1 ][ "name" ] == "Health", ;
        "discovery returns independent public metadata", @nFailures, @nChecks )
    M1Assert( ! hb_HHasKey( aCatalog[ 1 ], "handler" ) .AND. Len( aCatalog ) == 6, ;
        "discovery filters admin and handler internals", @nFailures, @nChecks )
    hSpec := { "name" => "Test.Fault", "version" => 1, "params" => "any", "result" => "any", ;
        "permission" => "service.call", "dependencies" => {}, "modes" => { "immediate" } }
    hCustom := HBBridgeRegistry()
    M1Assert( HBBridgeRegister( hCustom, hSpec, {|| Break( "test" ) } ) .AND. ;
        ! HBBridgeRegister( hCustom, hSpec, {|| NIL } ), "duplicate registration rejected", @nFailures, @nChecks )
    HBBridgeRegistrySeal( hCustom )
    hResult := HBBridgeDispatch( hCustom, "Test.Fault", NIL, hContext )
    M1Assert( hResult[ "code" ] == "SERVICE_ERROR", "handler failure contained in common core", @nFailures, @nChecks )
    M1Assert( ! HBBridgeRegister( hCustom, hSpec, {|| NIL } ), "sealed registry rejects mutation", @nFailures, @nChecks )
    FOR EACH cJson IN { '{"service":"Echo","params":null}', '{"service":"Echo","params":{"nested":[1,true,null]}}' }
        hb_jsonDecode( DispatcherRequest( cJson, hRegistry, hContext ), @hResult )
        M1Assert( hResult[ "success" ], "Protheus adapter preserves null and nested values", @nFailures, @nChecks )
    NEXT
    hb_jsonDecode( DispatcherRequest( '{"service":"Health"} trailing', hRegistry, hContext ), @hResult )
    M1Assert( hResult[ "code" ] == "INVALID_JSON", "trailing JSON garbage rejected", @nFailures, @nChecks )
RETURN
