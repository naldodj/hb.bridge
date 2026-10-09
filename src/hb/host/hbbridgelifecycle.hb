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

FUNCTION HBBridgeHostStart( hConfig, cError )

    LOCAL hRegistry, hHost, hListener

    cError := ""
    IF ! hb_mtvm() .OR. ! HBBridgeConfigValid( hConfig, @cError )
        IF Empty( cError )
            cError := "hbBridge requires multithreaded Harbour (-mt)"
        ENDIF
        RETURN NIL
    ENDIF
    IF ! hb_DirExists( hConfig[ "netioRoot" ] ) .AND. ! hb_DirBuild( hConfig[ "netioRoot" ] )
        cError := "Unable to prepare netioRoot"
        RETURN NIL
    ENDIF
    hRegistry := HBBridgeBuiltinRegistry( hConfig[ "sqlProfiles" ] )
    hHost := { "mutex" => hb_mutexCreate(), "stopMutex" => hb_mutexCreate(), ;
        "stopping" => .F., "started" => HBBridgeMonotonicMs(), "listeners" => {=>} }
    hListener := HBBridgeNetioStart( hConfig, hRegistry, hHost )
    IF Empty( hListener )
        cError := "Unable to start the NETIO endpoint"
        RETURN NIL
    ENDIF
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "netio" ] := hListener } )
    IF ! Empty( hConfig[ "adminPassword" ] )
        hListener := HBBridgeNetioStart( hConfig, hRegistry, hHost, .T. )
        IF Empty( hListener )
            cError := "Unable to start the administration endpoint"
            HBBridgeHostStop( hHost )
            RETURN NIL
        ENDIF
        hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "admin" ] := hListener } )
    ENDIF
    hListener := HBBridgeServerStart( hConfig[ "protheusPort" ], hConfig[ "maxWorkers" ], ;
        hConfig[ "protheusHost" ], hRegistry, HBBridgeContext( "protheus", hConfig[ "addonRoot" ], hHost ), hConfig )
    IF Empty( hListener )
        cError := "Unable to start the Protheus endpoint"
        HBBridgeHostStop( hHost )
        RETURN NIL
    ENDIF
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "protheus" ] := hListener } )
    IF hConfig[ "httpEnabled" ]
        hListener := HBBridgeHTTPStart( hConfig, hRegistry, hHost, @cError )
        IF Empty( hListener )
            HBBridgeHostStop( hHost )
            RETURN NIL
        ENDIF
        hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "listeners" ][ "http" ] := hListener } )
    ENDIF

RETURN hHost

FUNCTION HBBridgeHostRunning( hHost )
    LOCAL hListener
    IF hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "stopping" ] } )
        RETURN .F.
    ENDIF
    FOR EACH hListener IN hHost[ "listeners" ]
        IF ! HBBridgeServerRunning( hListener )
            RETURN .F.
        ENDIF
    NEXT
RETURN .T.

FUNCTION HBBridgeHostStop( hHost )
RETURN hb_mutexEval( hHost[ "stopMutex" ], {|| HostStopAndJoin( hHost ) } )

STATIC FUNCTION HostStopAndJoin( hHost )
    LOCAL cChannel, lOK := .T.
    hb_mutexEval( hHost[ "mutex" ], {|| hHost[ "stopping" ] := .T. } )
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        hb_mutexEval( hHost[ "listeners" ][ cChannel ][ "mutex" ], ;
            {|| hHost[ "listeners" ][ cChannel ][ "stopping" ] := .T. } )
    NEXT
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        IF cChannel == "protheus"
            lOK := HBBridgeServerStop( hHost[ "listeners" ][ cChannel ] ) .AND. lOK
        ELSEIF cChannel == "http"
            lOK := HBBridgeHTTPStop( hHost[ "listeners" ][ cChannel ] ) .AND. lOK
        ELSE
            lOK := HBBridgeNetioStop( hHost[ "listeners" ][ cChannel ] ) .AND. lOK
        ENDIF
    NEXT
RETURN lOK

FUNCTION HBBridgeHostStatus( hHost )
    IF ! HB_ISHASH( hHost )
        RETURN HBBridgeError( "HOST_UNAVAILABLE", "Host state is unavailable" )
    ENDIF
RETURN hb_mutexEval( hHost[ "mutex" ], {|| HostStatusLocked( hHost ) } )

STATIC FUNCTION HostStatusLocked( hHost )
    LOCAL hResult, cChannel, hListener
    hResult := {;
        "success" => .T.;
        ,"stopping" => hHost[ "stopping" ];
        ,"uptimeMs" => HBBridgeMonotonicMs() - hHost[ "started" ];
        ,"endpoints" => {=>};
        }
    FOR EACH cChannel IN hb_HKeys( hHost[ "listeners" ] )
        hListener := hHost[ "listeners" ][ cChannel ]
        hResult[ "endpoints" ][ cChannel ] := {;
                "host" => hListener[ "host" ];
                ,"port" => hListener[ "port" ];
                ,"active" => HBBridgeServerActive( hListener );
                ,"running" => HBBridgeServerRunning( hListener );
            }
        IF cChannel == "http"
            hResult[ "endpoints" ][ cChannel ][ "requests" ] := ;
                hb_mutexEval( hListener[ "mutex" ], {|| hListener[ "requests" ] } )
            hResult[ "endpoints" ][ cChannel ][ "rejected" ] := ;
                hb_mutexEval( hListener[ "mutex" ], {|| hListener[ "rejected" ] } )
        ENDIF
    NEXT
RETURN hResult
