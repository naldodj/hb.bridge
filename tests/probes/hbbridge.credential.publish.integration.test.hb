/* Released to Public Domain. Synthetic local publication integration only. */

PROCEDURE HBBridgeCredentialPublishIntegrationTests( nFailures, nChecks )
    LOCAL cBase := hb_cwd(), cConfigPath, cEnvelope, cError, cINI, cKeyBytes, cKeyPath, cLockPath, cPlan
    LOCAL cId := "fixture", cKeyId := "primary", cProfile := "mssql/example", cUser := "fixture_user"
    LOCAL cOld := "synthetic old password", cNew := "synthetic replacement password"
    LOCAL hConfig
#if defined( __PLATFORM__LINUX )
    LOCAL hPublished, hProfile
#endif
    LOCAL lConfigCreated := .F., lKeyCreated := .F., lLockOwned := .F., lPublished
    LOCAL nStatus := -1

    cKeyPath := HBBridgeAbsolutePath( "credential-publish-fixture.key", cBase )
    cConfigPath := HBBridgeAbsolutePath( "credential-publish-fixture.ini", cBase )
    cLockPath := cConfigPath + ".hbbridge.lock"
    BEGIN SEQUENCE WITH __BreakBlock()
        IF hb_FileExists( cKeyPath ) .OR. hb_FileExists( cConfigPath ) .OR. hb_FileExists( cLockPath )
            M1Assert( .F., "publication fixture paths are unused", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        lKeyCreated := HBBridgeCredentialCreateKey( cKeyPath, @cError )
        IF ! lKeyCreated
            M1Assert( .F., "publication fixture key is created", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        cKeyBytes := hb_MemoRead( cKeyPath )
        cEnvelope := HBBridgeCredentialEncrypt( cKeyPath, cProfile, cId, cKeyId, cUser, cOld, @cError )
        IF ! HB_ISSTRING( cEnvelope )
            M1Assert( .F., "publication fixture envelope is created", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        cINI := "# synthetic fixture; retain this line" + hb_eol() + ;
            "[SQL/" + cProfile + "]" + hb_eol() + "Driver=mssql" + hb_eol() + ;
            "Authentication=sql" + hb_eol() + "DSN=__HBBridgeMissingDSN__" + hb_eol() + ;
            "Credential=" + cId + hb_eol() + "[Credential/" + cId + "]" + hb_eol() + ;
            "User=" + cUser + hb_eol() + "KeyId=" + cKeyId + hb_eol() + "Password=" + cEnvelope + hb_eol() + ;
            "[Key/" + cKeyId + "]" + hb_eol() + "Provider=file" + hb_eol() + ;
            "Location=credential-publish-fixture.key" + hb_eol()
        lConfigCreated := .T.
        IF ! hb_MemoWrit( cConfigPath, cINI )
            M1Assert( .F., "publication fixture INI is written", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        hConfig := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
        IF ! HB_ISHASH( hConfig )
            M1Assert( .F., "publication fixture INI is parsed", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        cPlan := HBBridgeCredentialPrepareCheckedUpdate( cINI, hb_MemoRead( cConfigPath ), cBase, ;
            cProfile, cNew, hConfig, @cError )
        IF ! HB_ISSTRING( cPlan ) .OR. cError != ""
            M1Assert( .F., "authenticated publication update is prepared", @nFailures, @nChecks )
            Break( NIL )
        ENDIF
        M1Assert( hb_BAt( cNew, cPlan ) == 0 .AND. hb_BAt( "# synthetic fixture; retain this line", cPlan ) > 0, ;
            "prepared INI retains unrelated content and excludes plaintext", @nFailures, @nChecks )
        lLockOwned := .T.
        lPublished := HBBridgeCredentialPublish( cConfigPath, cINI, cPlan, @nStatus )
#if defined( __PLATFORM__LINUX )
        M1Assert( lPublished .AND. nStatus == 0 .AND. hb_MemoRead( cConfigPath ) == cPlan, ;
            "candidate publishes the prepared INI", @nFailures, @nChecks )
        IF lPublished .AND. nStatus == 0
            hPublished := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )
            IF HB_ISHASH( hPublished )
                hProfile := hPublished[ "sqlProfiles" ][ cProfile ]
            ENDIF
            M1Assert( HB_ISHASH( hProfile ) .AND. ;
                HBBridgeCredentialDecrypt( cKeyPath, cProfile, cId, cKeyId, cUser, ;
                    hProfile[ "credential" ][ "envelope" ], @cError ) == cNew, ;
                "published profile decrypts to the replacement", @nFailures, @nChecks )
            M1Assert( ! HBBridgeCredentialPublish( cConfigPath, cINI, cPlan, @nStatus ) .AND. ;
                nStatus == 4 .AND. hb_MemoRead( cConfigPath ) == cPlan, ;
                "stale publication preserves the updated INI", @nFailures, @nChecks )
        ENDIF
#else
        M1Assert( ! lPublished .AND. nStatus == 2 .AND. hb_MemoRead( cConfigPath ) == cINI, ;
            "unsupported publisher preserves the original INI", @nFailures, @nChecks )
#endif
        M1Assert( hb_MemoRead( cKeyPath ) == cKeyBytes, "publication preserves the private key", @nFailures, @nChecks )
    ALWAYS
        IF lConfigCreated .AND. hb_FileExists( cConfigPath )
            FErase( cConfigPath )
        ENDIF
        IF lKeyCreated .AND. hb_FileExists( cKeyPath )
            FErase( cKeyPath )
        ENDIF
        /* The unique test directory has no other participants or waiters. */
        IF lLockOwned .AND. hb_FileExists( cLockPath )
            FErase( cLockPath )
        ENDIF
    END SEQUENCE
RETURN
