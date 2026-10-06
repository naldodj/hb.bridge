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
FUNCTION HBBridgeBuiltinRegistry( hSQLProfiles )

    LOCAL hRegistry := HBBridgeRegistry()

    Builtin( hRegistry, "Health", "any", "service.call", { "hbbridge_zig" }, ;
        {| x, ctx | HBBridgeServiceHealth( x, ctx ) } )
    Builtin( hRegistry, "Echo", "any", "service.call", {}, ;
        {| x | { "success" => .T., "service" => "Echo", "params" => x } } )
    Builtin( hRegistry, "ADDON.Execute", "H", "addon.execute", { "hbcompiler", "hbhrb" }, ;
        {| x, ctx | HBBridgeServiceAddon( x, ctx ) } )
    Builtin( hRegistry, "Service.List", "any", "capabilities.read", {}, ;
        {| x, ctx | HBBridgeServiceList( x, ctx ) } )
    Builtin( hRegistry, "Core.Upper", "C", "core.call", { "hbextern" }, ;
        {| x | { "success" => .T., "result" => Upper( x ) } } )
    Builtin( hRegistry, "Core.Version", "any", "core.call", { "hbextern" }, ;
        {|| { "success" => .T., "result" => Version() } } )
    Builtin( hRegistry, "Admin.Status", "any", "admin.read", {}, ;
        {| x, ctx | HBBridgeServiceStatus( x, ctx ) } )
    IF HB_ISHASH( hSQLProfiles ) .AND. Len( hSQLProfiles ) > 0
        hSQLProfiles := hb_HClone( hSQLProfiles )
        Builtin( hRegistry, "RPCRDD.Query", "H", "service.call", { "rddsql", "sddsqlt3", "sddodbc" }, ;
            {| x | HBBridgeSQLQuery( x, hSQLProfiles ) } )
    ENDIF

RETURN HBBridgeRegistrySeal( hRegistry )

STATIC PROCEDURE Builtin( hRegistry, cName, cParams, cPermission, aDependencies, bHandler )
    HBBridgeRegister( hRegistry, { "name" => cName, "version" => 1, ;
        "params" => cParams, "result" => "H", "permission" => cPermission, ;
        "dependencies" => aDependencies, "modes" => { "immediate" } }, bHandler )
RETURN

FUNCTION HBBridgeServiceHealth( xParams, hContext )
    LOCAL hResult
    HB_SYMBOL_UNUSED( xParams )
    HB_SYMBOL_UNUSED( hContext )
    hb_jsonDecode( ZigEngineDispatch( '{}' ), @hResult )
RETURN hResult

FUNCTION HBBridgeServiceList( xParams, hContext )
    HB_SYMBOL_UNUSED( xParams )
RETURN { "success" => .T., "services" => HBBridgeCatalog( hContext[ "registry" ], hContext ), ;
    "nativeTypes" => { "U", "C", "L", "N", "D", "T", "A", "H" }, ;
    "hashKeys" => "C", "textEncoding" => "client-managed", "serviceVersion" => 1 }

FUNCTION HBBridgeServiceAddon( hParams, hContext )
    LOCAL cJson, hResult, cModule, cPart

    IF ! hb_HHasKey( hParams, "module" ) .OR. ! hb_HHasKey( hParams, "params" )
        RETURN HBBridgeError( "INVALID_PARAMS", "Modulo e parametros obrigatorios" )
    ENDIF
    cModule := hParams[ "module" ]
    IF ! HB_ISSTRING( cModule ) .OR. Empty( cModule )
        RETURN HBBridgeError( "INVALID_MODULE", "Modulo invalido" )
    ENDIF
    cModule := StrTran( cModule, "\", "/" )
    IF Left( cModule, 1 ) == "/" .OR. ":" $ cModule .OR. Chr( 0 ) $ cModule
        RETURN HBBridgeError( "INVALID_MODULE", "Modulo deve ser relativo a addonRoot" )
    ENDIF
    FOR EACH cPart IN hb_ATokens( cModule, "/" )
        IF cPart == ".." .OR. Empty( cPart )
            RETURN HBBridgeError( "INVALID_MODULE", "Caminho de modulo invalido" )
        ENDIF
    NEXT
    /* Existing addons take/return JSON. Keep their ABI explicit here. */
    cJson := ExecuteAddonHRB( cModule, hParams[ "params" ], hContext[ "addonRoot" ] )
    IF ! HB_ISSTRING( cJson ) .OR. Empty( cJson )
        RETURN HBBridgeError( "ADDON_RESULT", "Addon ausente ou sem resposta" )
    ENDIF
    IF hb_jsonDecode( cJson, @hResult ) == 0 .OR. ! HB_ISHASH( hResult )
        RETURN HBBridgeError( "ADDON_RESULT", "Resposta JSON invalida do addon" )
    ENDIF
RETURN hResult

FUNCTION HBBridgeServiceStatus( xParams, hContext )
    HB_SYMBOL_UNUSED( xParams )
RETURN HBBridgeHostStatus( hContext[ "state" ] )
