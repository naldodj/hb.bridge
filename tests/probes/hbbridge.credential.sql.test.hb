/* Released to Public Domain. Focused protected SQL profile checks. */

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE HBBridgeCredentialSQLTest( cMode )

    LOCAL cCase, cPrefix := "--terminal-update-fixture="
    LOCAL nFailures := 0, nChecks := 0

    hb_cdpSelect( "UTF8EX" )
    IF PCount() == 0
        HBBridgeCredentialConfigTests( @nFailures, @nChecks )
        HBBridgeCredentialPublishIntegrationTests( @nFailures, @nChecks )
    ELSE
        IF PCount() != 1 .OR. !( Left( cMode, Len( cPrefix ) ) == cPrefix )
            ErrorLevel( 1 )
            RETURN
        ENDIF
        cCase := SubStr( cMode, Len( cPrefix ) + 1 )
        IF AScan( { "publish", "cancel", "redirect", "conflict" }, {| cAllowed | cAllowed == cCase } ) == 0
            ErrorLevel( 1 )
            RETURN
        ENDIF
#if defined( __PLATFORM__LINUX )
        BEGIN SEQUENCE WITH __BreakBlock()
            HBBridgeCredentialPublishIntegrationTests( @nFailures, @nChecks, cCase )
        RECOVER
            M1Assert( .F., "terminal update fixture completed", @nFailures, @nChecks )
        END SEQUENCE
#else
        OutStd( "CREDENTIAL_EDIT_UNSUPPORTED" + hb_eol() )
        ErrorLevel( 1 )
        RETURN
#endif
    ENDIF
    OutStd( "Protected SQL credential checks=" + hb_ntos( nChecks ) + "; failures=" + hb_ntos( nFailures ) + hb_eol() )
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )
RETURN

PROCEDURE M1Assert( lOK, cMessage, nFailures, nChecks )
    nChecks++
    IF ! lOK
        nFailures++
    ENDIF
    OutStd( iif( lOK, "PASS: ", "FAIL: " ) + cMessage + hb_eol() )
RETURN
