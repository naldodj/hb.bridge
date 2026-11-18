/* Released to Public Domain. Synthetic key access-permission probe. */

PROCEDURE Main( cMode, cKeyPath )

    LOCAL cEnvelope, cError, cPassword := "synthetic"
    LOCAL lOK := .F.

    DO CASE
    CASE cMode == "create"
        IF HBBridgeCredentialCreateKey( cKeyPath, @cError )
            cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, "fixture", "credential", "key", "user", cPassword, @cError )
            lOK := HB_ISSTRING( cEnvelope ) .AND. hb_MemoWrit( cKeyPath + ".envelope", cEnvelope )
        ENDIF
    CASE cMode == "accept"
        cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, "fixture", "credential", "key", "user", cPassword, @cError )
        lOK := HB_ISSTRING( cEnvelope ) .AND. cError == NIL .AND. ;
            HBBridgeCredentialDecrypt( cKeyPath, "fixture", "credential", "key", "user", cEnvelope, @cError ) == cPassword .AND. ;
            cError == NIL
    CASE cMode == "reject"
        cEnvelope := hb_MemoRead( cKeyPath + ".envelope" )
        lOK := HBBridgeCredentialEncrypt( cKeyPath, "fixture", "credential", "key", "user", cPassword, @cError ) == NIL .AND. ;
            cError == "KEY_PERMISSIONS_UNSAFE"
        IF lOK
            lOK := HBBridgeCredentialDecrypt( cKeyPath, "fixture", "credential", "key", "user", cEnvelope, @cError ) == NIL .AND. ;
                cError == "KEY_PERMISSIONS_UNSAFE"
        ENDIF
    ENDCASE
    OutStd( iif( lOK, "PASS ", "FAIL " ) + "credential permissions " + cMode + hb_eol() )
    ErrorLevel( iif( lOK, 0, 1 ) )

RETURN
