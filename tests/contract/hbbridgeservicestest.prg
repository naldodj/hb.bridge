PROCEDURE m1servicetests( nFailures, nChecks )

    LOCAL hRegistry := hbbridgebuiltinregistry(), hContext := hbbridgecontext( "test" )
    LOCAL hResult, xBad, aCycle := {}, hSpec, hCustom, aCatalog, cJson

    hResult := hbbridgedispatch( hRegistry, "Core.Upper", "harbour", hContext )
    m1assert( hResult[ "result" ] == "HARBOUR", "registered core function", @nFailures, @nChecks )
    FOR EACH xBad IN { "1", 0, 1.5, .T. }
        hResult := hbbridgedispatch( hRegistry, "Echo", NIL, hContext, xBad )
        m1assert( hResult[ "code" ] == "INVALID_VERSION", "invalid service version rejected", @nFailures, @nChecks )
    NEXT
    hResult := hbbridgedispatch( hRegistry, "Echo", NIL, hContext, 2 )
    m1assert( hResult[ "code" ] == "SERVICE_NOT_FOUND", "unknown service version rejected", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "Admin.Status", NIL, hContext )
    m1assert( hResult[ "code" ] == "FORBIDDEN", "data context cannot invoke admin service", @nFailures, @nChecks )
    hResult := hbbridgedispatch( hRegistry, "Core.Upper", 1, hContext )
    m1assert( hResult[ "code" ] == "INVALID_PARAMS", "signature enforced", @nFailures, @nChecks )
    AAdd( aCycle, aCycle )
    m1assert( ! hbbridgevalueallowed( aCycle ) .AND. ! hbbridgevalueallowed( {|| NIL } ) .AND. ;
        ! hbbridgevalueallowed( { 1 => "numeric key" } ), "cycles, executable values and nonstring keys rejected", @nFailures, @nChecks )
    ASize( aCycle, 0 )
    hResult := hbbridgedispatch( hRegistry, "ADDON.Execute", ;
        { "module" => "../outside.hrb", "params" => {=>} }, hContext )
    m1assert( hResult[ "code" ] == "INVALID_MODULE", "addon traversal rejected", @nFailures, @nChecks )
    aCatalog := hbbridgecatalog( hRegistry, hContext )
    aCatalog[ 1 ][ "name" ] := "modified"
    m1assert( hbbridgecatalog( hRegistry, hContext )[ 1 ][ "name" ] == "Health", ;
        "discovery returns independent public metadata", @nFailures, @nChecks )
    m1assert( ! hb_HHasKey( aCatalog[ 1 ], "handler" ) .AND. Len( aCatalog ) == 6, ;
        "discovery filters admin and handler internals", @nFailures, @nChecks )
    hSpec := { "name" => "Test.Fault", "version" => 1, "params" => "any", "result" => "any", ;
        "permission" => "service.call", "dependencies" => {}, "modes" => { "immediate" } }
    hCustom := hbbridgeregistry()
    m1assert( hbbridgeregister( hCustom, hSpec, {|| Break( "test" ) } ) .AND. ;
        ! hbbridgeregister( hCustom, hSpec, {|| NIL } ), "duplicate registration rejected", @nFailures, @nChecks )
    hbbridgeregistryseal( hCustom )
    hResult := hbbridgedispatch( hCustom, "Test.Fault", NIL, hContext )
    m1assert( hResult[ "code" ] == "SERVICE_ERROR", "handler failure contained in common core", @nFailures, @nChecks )
    m1assert( ! hbbridgeregister( hCustom, hSpec, {|| NIL } ), "sealed registry rejects mutation", @nFailures, @nChecks )
    FOR EACH cJson IN { '{"service":"Echo","params":null}', '{"service":"Echo","params":{"nested":[1,true,null]}}' }
        hb_jsonDecode( dispatcherrequest( cJson, hRegistry, hContext ), @hResult )
        m1assert( hResult[ "success" ], "Protheus adapter preserves null and nested values", @nFailures, @nChecks )
    NEXT
    hb_jsonDecode( dispatcherrequest( '{"service":"Health"} trailing', hRegistry, hContext ), @hResult )
    m1assert( hResult[ "code" ] == "INVALID_JSON", "trailing JSON garbage rejected", @nFailures, @nChecks )
RETURN
