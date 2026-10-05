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

FUNCTION hbbridgehoststart( hConfig, cError )

    LOCAL hRegistry, hHost, hListener

    cError := ""
    IF ! hb_mtvm() .OR. ! hbbridgeconfigvalid( hConfig, @cError )
        IF Empty( cError )
            cError := "hbBridge requer Harbour multithread (-mt)"
        ENDIF
        RETURN NIL
    ENDIF
    IF ! hb_DirExists( hConfig[ "netioRoot" ] ) .AND. ! hb_DirBuild( hConfig[ "netioRoot" ] )
        cError := "Nao foi possivel preparar netioRoot"
        RETURN NIL
    ENDIF
    hRegistry := hbbridgebuiltinregistry( hConfig[ "sqlProfiles" ] )
    hHost := { "mutex" => hb_mutexCreate(), "stopMutex" => hb_mutexCreate(), ;
        "stopping" => .F., "started" => hbbridgemonotonicms(), "listeners" => {=>} }
    hListener := hbbridgenetiostart( hConfig, hRegistry, hHost )
    IF Empty( hListener )
        cError := "Falha ao iniciar endpoint NETIO"
        RETURN NIL
    ENDIF
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "netio" ] := hListener } )
    IF ! Empty( hConfig[ "adminPassword" ] )
        hListener := hbbridgenetiostart( hConfig, hRegistry, hHost, .T. )
        IF Empty( hListener )
            cError := "Falha ao iniciar endpoint de administracao"
            hbbridgehoststop( hHost )
            RETURN NIL
        ENDIF
        hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "admin" ] := hListener } )
    ENDIF
    hListener := hbbridgeserverstart( hConfig[ "protheusPort" ], hConfig[ "maxWorkers" ], ;
        hConfig[ "protheusHost" ], hRegistry, hbbridgecontext( "protheus", hConfig[ "addonRoot" ], hHost ), hConfig )
    IF Empty( hListener )
        cError := "Falha ao iniciar endpoint Protheus"
        hbbridgehoststop( hHost )
        RETURN NIL
    ENDIF
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "protheus" ] := hListener } )

RETURN hHost

FUNCTION hbbridgehostrunning( hHost )
    LOCAL hListener
    IF hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "stopping" ] } )
        RETURN .F.
    ENDIF
    FOR EACH hListener IN hHost[ "listeners" ]
        IF ! hbbridgeserverrunning( hListener )
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

FUNCTION hbbridgehoststop( hHost )
RETURN hb_mutexEval( hHost[ "stopMutex" ], {|| hoststopandjoin( hHost ) } )

STATIC FUNCTION hoststopandjoin( hHost )
    LOCAL cChannel, lOK := .T.
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "stopping" ] := .T. } )
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        hb_mutexEval( hHost[ "listeners" ][ cChannel ][ "mutex" ], ;
            {|| hHost[ "listeners" ][ cChannel ][ "stopping" ] := .T. } )
    NEXT
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        IF cChannel == "protheus"
            lOK := hbbridgeserverstop( hHost[ "listeners" ][ cChannel ] ) .AND. lOK
        ELSE
            lOK := hbbridgenetiostop( hHost[ "listeners" ][ cChannel ] ) .AND. lOK
        ENDIF
    NEXT
RETURN lOK

FUNCTION hbbridgehoststatus( hHost )
    IF ! HB_ISHASH( hHost )
        RETURN hbbridgeerror( "HOST_UNAVAILABLE", "Estado do host indisponivel" )
    ENDIF
RETURN hb_mutexEval( hHost[ "mutex" ], {|| hoststatuslocked( hHost ) } )

STATIC FUNCTION hoststatuslocked( hHost )
    LOCAL hResult, cChannel, hListener
    hResult := {;
        "success" => .T.;
        ,"stopping" => hHost[ "stopping" ];
        ,"uptimeMs" => hbbridgemonotonicms() - hHost[ "started" ];
        ,"endpoints" => {=>};
        }
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        hListener := hHost[ "listeners" ][ cChannel ]
        hResult[ "endpoints" ][ cChannel ] := {;
                "host" => hListener[ "host" ];
                ,"port" => hListener[ "port" ];
                ,"active" => hbbridgeserveractive( hListener );
                ,"running" => hbbridgeserverrunning( hListener );
            }
    NEXT
RETURN hResult
