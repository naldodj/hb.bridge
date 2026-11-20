/* Released to Public Domain. Synthetic interactive terminal-input probe. */

PROCEDURE HBBridgeCredentialTerminalProbe()
    LOCAL cSecret
    LOCAL nOriginal := HBBridgeTerminalTestMode(), nStatus := -1

    cSecret := HBBridgeCredentialReadSecret( @nStatus )
    IF nOriginal != NIL .AND. HBBridgeTerminalTestMode() == nOriginal
        OutStd( "TERMINAL_MODE_RESTORED" + hb_eol() )
    ENDIF
    IF nStatus == 0 .AND. ( cSecret == "synthetic-" + hb_UTF8Chr( 233 ) + "-secret" .OR. ;
        cSecret == "  synthetic-" + hb_UTF8Chr( 233 ) + "-secret  " .OR. ;
        cSecret == "synthetic-" + hb_UTF8Chr( 128640 ) + "-secret" )
        OutStd( "TERMINAL_PROBE_MATCH" + hb_eol() )
        ErrorLevel( 0 )
    ELSEIF nStatus == 0 .AND. cSecret == Replicate( "x", 4096 )
        OutStd( "TERMINAL_LIMIT_MATCH" + hb_eol() )
        ErrorLevel( 0 )
    ELSE
        OutStd( "TERMINAL_PROBE_STATUS=" + hb_ntos( nStatus ) + hb_eol() )
        ErrorLevel( 1 )
    ENDIF
    cSecret := NIL
RETURN
