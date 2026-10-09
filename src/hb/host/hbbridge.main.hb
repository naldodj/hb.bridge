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

#include "inkey.ch"
#include "hbinkey.ch"

PROCEDURE Main( ... )

    LOCAL aArgs := hb_AParams(), hConfig, hHost, cError, nKey, hStatus, cChannel

    IF AScan( aArgs, {| cArg | cArg == "--help" .OR. cArg == "-h" } ) > 0
        OutStd( HBBridgeConfigHelp() )
        RETURN
    ENDIF
    hConfig := HBBridgeConfig( aArgs, @cError )
    IF hConfig == NIL
        OutErr( cError + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    IF AScan( aArgs, {| cArg | cArg == "--config-info" } ) > 0
        OutStd( hb_jsonEncode( HBBridgeConfigInfo( hConfig ) ) + hb_eol() )
        RETURN
    ENDIF
    hHost := HBBridgeHostStart( hConfig, @cError )
    IF hHost == NIL
        OutErr( cError + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    hStatus := HBBridgeHostStatus( hHost )
    FOR EACH cChannel IN hb_HKeys( hStatus[ "endpoints" ] )
        OutStd( "hbBridge " + cChannel + " " + hStatus[ "endpoints" ][ cChannel ][ "host" ] + ;
            ":" + hb_ntos( hStatus[ "endpoints" ][ cChannel ][ "port" ] ) + hb_eol() )
    NEXT
    IF Len( hConfig[ "sqlProfiles" ] ) > 0
        OutStd( "hbBridge RPCRDD.Query enabled; SQL profiles=" + ;
            hb_ntos( Len( hConfig[ "sqlProfiles" ] ) ) + hb_eol() )
    ELSE
        OutStd( "hbBridge RPCRDD.Query disabled; sqlProfiles is empty" + hb_eol() )
    ENDIF
    OutStd( "CTRL+Q para encerrar" + hb_eol() )
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        DO WHILE HBBridgeHostRunning( hHost )
            nKey := Inkey( 0.1, hb_bitOr( INKEY_ALL, HB_INKEY_GTEVENT ) )
            IF nKey == HB_K_CTRL_Q
                EXIT
            ENDIF
        ENDDO
        IF ! HBBridgeHostRunning( hHost )
            ErrorLevel( 1 )
        ENDIF
    RECOVER
        ErrorLevel( 1 )
    ALWAYS
        HBBridgeHostStop( hHost )
    END SEQUENCE
RETURN
