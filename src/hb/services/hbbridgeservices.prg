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

/* Services exchange Harbour values. JSON conversions belong to external ABIs. */
FUNCTION hbbridgebuiltinregistry( hSQLProfiles )

    LOCAL hRegistry := hbbridgeregistry()

    builtin( hRegistry, "Health", "any", "service.call", { "hbbridge_zig" }, ;
        {| x, ctx | hbbridgeservicehealth( x, ctx ) } )
    builtin( hRegistry, "Echo", "any", "service.call", {}, ;
        {| x | { "success" => .T., "service" => "Echo", "params" => x } } )
    builtin( hRegistry, "ADDON.Execute", "H", "addon.execute", { "hbcompiler", "hbhrb" }, ;
        {| x, ctx | hbbridgeserviceaddon( x, ctx ) } )
    builtin( hRegistry, "Service.List", "any", "capabilities.read", {}, ;
        {| x, ctx | hbbridgeservicelist( x, ctx ) } )
    builtin( hRegistry, "Core.Upper", "C", "core.call", { "hbextern" }, ;
        {| x | { "success" => .T., "result" => Upper( x ) } } )
    builtin( hRegistry, "Core.Version", "any", "core.call", { "hbextern" }, ;
        {|| { "success" => .T., "result" => Version() } } )
    builtin( hRegistry, "Admin.Status", "any", "admin.read", {}, ;
        {| x, ctx | hbbridgeservicestatus( x, ctx ) } )
    IF HB_ISHASH( hSQLProfiles ) .AND. Len( hSQLProfiles ) > 0
        hSQLProfiles := hb_HClone( hSQLProfiles )
        builtin( hRegistry, "RPCRDD.Query", "H", "service.call", { "rddsql", "sddsqlt3", "sddodbc" }, ;
            {| x | hbbridgesqlquery( x, hSQLProfiles ) } )
    ENDIF

RETURN hbbridgeregistryseal( hRegistry )

STATIC PROCEDURE builtin( hRegistry, cName, cParams, cPermission, aDependencies, bHandler )
    hbbridgeregister( hRegistry, { "name" => cName, "version" => 1, ;
        "params" => cParams, "result" => "H", "permission" => cPermission, ;
        "dependencies" => aDependencies, "modes" => { "immediate" } }, bHandler )
RETURN

FUNCTION hbbridgeservicehealth( xParams, hContext )
    LOCAL hResult
    HB_SYMBOL_UNUSED( xParams )
    HB_SYMBOL_UNUSED( hContext )
    hb_jsonDecode( zigengine_dispatch( '{}' ), @hResult )
RETURN hResult

FUNCTION hbbridgeservicelist( xParams, hContext )
    HB_SYMBOL_UNUSED( xParams )
RETURN { "success" => .T., "services" => hbbridgecatalog( hContext[ "registry" ], hContext ), ;
    "nativeTypes" => { "U", "C", "L", "N", "D", "T", "A", "H" }, ;
    "hashKeys" => "C", "textEncoding" => "client-managed", "serviceVersion" => 1 }

FUNCTION hbbridgeserviceaddon( hParams, hContext )
    LOCAL cJson, hResult, cModule, cPart

    IF ! hb_HHasKey( hParams, "module" ) .OR. ! hb_HHasKey( hParams, "params" )
        RETURN hbbridgeerror( "INVALID_PARAMS", "Modulo e parametros obrigatorios" )
    ENDIF
    cModule := hParams[ "module" ]
    IF ! HB_ISSTRING( cModule ) .OR. Empty( cModule )
        RETURN hbbridgeerror( "INVALID_MODULE", "Modulo invalido" )
    ENDIF
    cModule := StrTran( cModule, "\", "/" )
    IF Left( cModule, 1 ) == "/" .OR. ":" $ cModule .OR. Chr( 0 ) $ cModule
        RETURN hbbridgeerror( "INVALID_MODULE", "Modulo deve ser relativo a addonRoot" )
    ENDIF
    FOR EACH cPart IN hb_ATokens( cModule, "/" )
        IF cPart == ".." .OR. Empty( cPart )
            RETURN hbbridgeerror( "INVALID_MODULE", "Caminho de modulo invalido" )
        ENDIF
    NEXT
    /* Existing addons take/return JSON. Keep their ABI explicit here. */
    cJson := executeaddonhrb( cModule, hParams[ "params" ], hContext[ "addonRoot" ] )
    IF ! HB_ISSTRING( cJson ) .OR. Empty( cJson )
        RETURN hbbridgeerror( "ADDON_RESULT", "Addon ausente ou sem resposta" )
    ENDIF
    IF hb_jsonDecode( cJson, @hResult ) == 0 .OR. ! HB_ISHASH( hResult )
        RETURN hbbridgeerror( "ADDON_RESULT", "Resposta JSON invalida do addon" )
    ENDIF
RETURN hResult

FUNCTION hbbridgeservicestatus( xParams, hContext )
    HB_SYMBOL_UNUSED( xParams )
RETURN hbbridgehoststatus( hContext[ "state" ] )
