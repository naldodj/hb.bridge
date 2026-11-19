/* Released to Public Domain. Prepare a context-bound credential update. */

FUNCTION HBBridgeCredentialPrepareUpdate( cContents, cBase, cProfile, cPassword, hDefaults, cError )
    LOCAL cBody, cExisting, cEnvelope, cFailure, cPlan, cVerified
    LOCAL cBOM := Chr( 239 ) + Chr( 187 ) + Chr( 191 )
    LOCAL hBound, hCredential, hFile, hNormalized, hProfile, hRaw
    LOCAL nReferences := 0

    cError := "INVALID_CREDENTIAL_UPDATE"
    IF ! HB_ISSTRING( cContents ) .OR. ! HB_ISSTRING( cBase ) .OR. Empty( cBase ) .OR. ;
        ! HB_ISSTRING( cProfile ) .OR. Empty( cProfile ) .OR. ! HB_ISSTRING( cPassword ) .OR. ;
        ! HB_ISHASH( hDefaults )
        RETURN NIL
    ENDIF
    cBody := cContents
    IF hb_BLeft( cBody, 3 ) == cBOM
        cBody := hb_BSubStr( cBody, 4 )
    ENDIF
    BEGIN SEQUENCE WITH {| oError | Break( oError ) }
        hFile := HBBridgeConfigINI( cBody, hDefaults, @cFailure )
        IF ! HB_ISHASH( hFile ) .OR. ! hb_HHasKey( hFile, "sqlProfiles" ) .OR. ;
            ! hb_HHasKey( hFile, "credentials" ) .OR. ! hb_HHasKey( hFile, "credentialKeys" )
            Break( NIL )
        ENDIF
        hBound := HBBridgeCredentialBindProfiles( hFile[ "sqlProfiles" ], hFile[ "credentials" ], ;
            hFile[ "credentialKeys" ], cBase, @cFailure )
        IF ! HB_ISHASH( hBound )
            Break( NIL )
        ENDIF
        hNormalized := HBBridgeSQLProfiles( hBound, cBase, @cFailure )
        IF ! HB_ISHASH( hNormalized ) .OR. ! hb_HHasKey( hNormalized, cProfile )
            Break( NIL )
        ENDIF
        hProfile := hNormalized[ cProfile ]
        IF ! HB_ISHASH( hProfile ) .OR. hb_HGetDef( hProfile, "driver", "" ) != "mssql" .OR. ;
            ! HBBridgeCredentialBoundValid( hb_HGetDef( hProfile, "credential", NIL ) )
            Break( NIL )
        ENDIF
        hCredential := hProfile[ "credential" ]
        /* One envelope is bound to one profile; do not invalidate other references. */
        FOR EACH hRaw IN hFile[ "sqlProfiles" ]
            IF HB_ISHASH( hRaw ) .AND. hb_HGetDef( hRaw, "credential", NIL ) == hCredential[ "id" ]
                nReferences++
            ENDIF
        NEXT
        IF nReferences != 1
            Break( NIL )
        ENDIF
        cExisting := HBBridgeCredentialDecrypt( hCredential[ "keyPath" ], cProfile, hCredential[ "id" ], ;
            hCredential[ "keyId" ], hCredential[ "user" ], hCredential[ "envelope" ], @cFailure )
        IF ! HB_ISSTRING( cExisting )
            Break( NIL )
        ENDIF
        cExisting := NIL
        cEnvelope := HBBridgeCredentialEncrypt( hCredential[ "keyPath" ], cProfile, hCredential[ "id" ], ;
            hCredential[ "keyId" ], hCredential[ "user" ], cPassword, @cFailure )
        IF ! HB_ISSTRING( cEnvelope )
            Break( NIL )
        ENDIF
        cVerified := HBBridgeCredentialDecrypt( hCredential[ "keyPath" ], cProfile, hCredential[ "id" ], ;
            hCredential[ "keyId" ], hCredential[ "user" ], cEnvelope, @cFailure )
        IF ! HB_ISSTRING( cVerified ) .OR. !( cVerified == cPassword )
            Break( NIL )
        ENDIF
        cVerified := NIL
        cPlan := HBBridgeCredentialPlanINI( cContents, hCredential[ "id" ], cEnvelope, hDefaults, @cFailure )
        IF ! HB_ISSTRING( cPlan )
            Break( NIL )
        ENDIF
        cError := ""
    RECOVER
        cPlan := NIL
    ALWAYS
        cExisting := NIL
        cVerified := NIL
    END SEQUENCE
RETURN cPlan
