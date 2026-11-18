/* Released to Public Domain. Cross-platform synthetic credential fixture. */

REQUEST HB_CODEPAGE_UTF8EX

PROCEDURE Main( cMode, cDirectory )

    LOCAL cEnvelope, cError, cKeyPath, cEnvelopePath
    LOCAL cPassword := " synthetic;" + hb_UTF8Chr( 233 ) + hb_UTF8Chr( 128640 ) + " "
    LOCAL lOK := .F.

    hb_cdpSelect( "UTF8EX" )
    IF ! HB_ISSTRING( cDirectory ) .OR. ! hb_DirExists( cDirectory )
        OutErr( "Synthetic fixture directory is unavailable." + hb_eol() )
        ErrorLevel( 1 )
        RETURN
    ENDIF
    cKeyPath := cDirectory + hb_ps() + "portability.key"
    cEnvelopePath := cDirectory + hb_ps() + "portability.envelope"
    DO CASE
    CASE cMode == "create"
        IF ! hb_FileExists( cKeyPath ) .AND. ! hb_FileExists( cEnvelopePath ) .AND. ;
            HBBridgeCredentialCreateKey( cKeyPath, @cError )
            cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, "mssql/example", "fixture", "main", "reader", cPassword, @cError )
            lOK := HB_ISSTRING( cEnvelope ) .AND. cError == NIL .AND. hb_MemoWrit( cEnvelopePath, cEnvelope )
        ENDIF
    CASE cMode == "verify"
        cEnvelope := hb_MemoRead( cEnvelopePath )
        lOK := HBBridgeCredentialDecrypt( cKeyPath, "mssql/example", "fixture", "main", "reader", cEnvelope, @cError ) == cPassword .AND. ;
            cError == NIL
        IF lOK
            lOK := HBBridgeCredentialDecrypt( cKeyPath, "mssql/other", "fixture", "main", "reader", cEnvelope, @cError ) == NIL .AND. ;
                cError == "AUTHENTICATION_FAILED"
        ENDIF
        IF lOK
            lOK := HBBridgeCredentialDecrypt( cKeyPath, "mssql/example", "other", "main", "reader", cEnvelope, @cError ) == NIL .AND. ;
                cError == "AUTHENTICATION_FAILED"
        ENDIF
        IF lOK
            lOK := HBBridgeCredentialDecrypt( cKeyPath, "mssql/example", "fixture", "other", "reader", cEnvelope, @cError ) == NIL .AND. ;
                cError == "AUTHENTICATION_FAILED"
        ENDIF
        IF lOK
            lOK := HBBridgeCredentialDecrypt( cKeyPath, "mssql/example", "fixture", "main", "other", cEnvelope, @cError ) == NIL .AND. ;
                cError == "AUTHENTICATION_FAILED"
        ENDIF
    ENDCASE
    OutStd( iif( lOK, "PASS ", "FAIL " ) + "synthetic credential portability " + cMode + hb_eol() )
    ErrorLevel( iif( lOK, 0, 1 ) )

RETURN
