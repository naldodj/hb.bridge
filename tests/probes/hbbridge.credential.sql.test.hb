/* Released to Public Domain. Focused protected SQL profile checks. */

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE HBBridgeCredentialSQLTest()

    LOCAL nFailures := 0, nChecks := 0

    hb_cdpSelect( "UTF8EX" )
    HBBridgeCredentialConfigTests( @nFailures, @nChecks )
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
