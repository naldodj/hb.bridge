/* Released to Public Domain. Synthetic interrupted key-creation probe. */

PROCEDURE Main( cPath, cExpectedError )

    LOCAL cError

    IF ! HBBridgeCredentialCreateKey( cPath, @cError )
        IF HB_ISSTRING( cExpectedError ) .AND. cError == cExpectedError
            OutStd( "Expected synthetic key-creation error received." + hb_eol() )
            RETURN
        ENDIF
        OutErr( "Synthetic key creation failed." + hb_eol() )
        ErrorLevel( 1 )
    ELSEIF HB_ISSTRING( cExpectedError )
        OutErr( "Synthetic key creation unexpectedly succeeded." + hb_eol() )
        ErrorLevel( 1 )
    ENDIF
RETURN
