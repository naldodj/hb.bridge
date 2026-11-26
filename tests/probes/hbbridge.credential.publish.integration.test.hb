/* Released to Public Domain. Synthetic local publication integration only. */

PROCEDURE HBBridgeCredentialPublishIntegrationTests( nFailures, nChecks, cTerminalCase )
    LOCAL cBase := hb_cwd(), cConfigPath, cEnvelope, cError, cINI, cKeyBytes, cKeyPath, cLockPath, cPlan
    LOCAL cId := "fixture", cKeyId := "primary", cProfile := "mssql/example", cUser := "fixture_user"
    LOCAL cOld := "synthetic old password", cNew := "synthetic replacement password"
#if defined( __PLATFORM__LINUX )
    LOCAL cOutcome, cObserved
#endif
    LOCAL hConfig
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
        lLockOwned := .T.
        IF HB_ISSTRING( cTerminalCase )
#if defined( __PLATFORM__LINUX )
            cNew := "  synthetic-" + hb_UTF8Chr( 233 ) + "-replacement  "
            cOutcome := TerminalFixtureUpdate( cConfigPath, cBase, cProfile, hConfig )
            M1Assert( cOutcome == cTerminalCase, "terminal update outcome", @nFailures, @nChecks )
            cObserved := hb_MemoRead( cConfigPath )
            DO CASE
            CASE cTerminalCase == "publish"
                M1Assert( PublishedMatches( cConfigPath, cProfile, cNew ) .AND. ;
                    hb_BAt( cNew, cObserved ) == 0, "saved credential reopens with terminal input", @nFailures, @nChecks )
            CASE cTerminalCase == "conflict"
                M1Assert( cObserved == cINI + "# synthetic concurrent edit" + hb_eol(), ;
                    "concurrent edit survives the terminal session", @nFailures, @nChecks )
            OTHERWISE
                M1Assert( cObserved == cINI, "input refusal preserves the original INI", @nFailures, @nChecks )
            ENDCASE
#endif
        ELSE
            cPlan := HBBridgeCredentialPrepareCheckedUpdate( cINI, hb_MemoRead( cConfigPath ), cBase, ;
                cProfile, cNew, hConfig, @cError )
            IF ! HB_ISSTRING( cPlan ) .OR. cError != ""
                M1Assert( .F., "authenticated publication update is prepared", @nFailures, @nChecks )
                Break( NIL )
            ENDIF
            M1Assert( hb_BAt( cNew, cPlan ) == 0 .AND. hb_BAt( "# synthetic fixture; retain this line", cPlan ) > 0, ;
                "prepared INI retains unrelated content and excludes plaintext", @nFailures, @nChecks )
            lPublished := HBBridgeCredentialPublish( cConfigPath, cINI, cPlan, @nStatus )
#if defined( __PLATFORM__LINUX )
            M1Assert( lPublished .AND. nStatus == 0 .AND. hb_MemoRead( cConfigPath ) == cPlan, ;
                "candidate publishes the prepared INI", @nFailures, @nChecks )
            IF lPublished .AND. nStatus == 0
                M1Assert( PublishedMatches( cConfigPath, cProfile, cNew ), ;
                    "published profile decrypts to the replacement", @nFailures, @nChecks )
                M1Assert( ! HBBridgeCredentialPublish( cConfigPath, cINI, cPlan, @nStatus ) .AND. ;
                    nStatus == 4 .AND. hb_MemoRead( cConfigPath ) == cPlan, ;
                    "stale publication preserves the updated INI", @nFailures, @nChecks )
            ENDIF
#else
            M1Assert( ! lPublished .AND. nStatus == 2 .AND. hb_MemoRead( cConfigPath ) == cINI, ;
                "unsupported publisher preserves the original INI", @nFailures, @nChecks )
#endif
        ENDIF
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

#if defined( __PLATFORM__LINUX )
STATIC FUNCTION PublishedMatches( cConfigPath, cProfile, cExpected )
    LOCAL cError
    LOCAL hProfile, hPublished := HBBridgeConfig( { "-config=" + cConfigPath }, @cError )

    IF ! HB_ISHASH( hPublished )
        RETURN .F.
    ENDIF
    hProfile := hb_HGetDef( hPublished[ "sqlProfiles" ], cProfile, NIL )
    IF ! HB_ISHASH( hProfile ) .OR. ! HBBridgeCredentialBoundValid( hb_HGetDef( hProfile, "credential", NIL ) )
        RETURN .F.
    ENDIF
    hProfile := hProfile[ "credential" ]
RETURN HBBridgeCredentialDecrypt( hProfile[ "keyPath" ], cProfile, hProfile[ "id" ], hProfile[ "keyId" ], ;
    hProfile[ "user" ], hProfile[ "envelope" ], @cError ) == cExpected

STATIC FUNCTION TerminalFixtureUpdate( cConfigPath, cBase, cProfile, hConfig )
    LOCAL cError, cExpected, cObserved, cPassword, cPlan
    LOCAL nStatus := -1

    cExpected := HBBridgeCredentialSnapshot( cConfigPath, @nStatus )
    IF ! HB_ISSTRING( cExpected ) .OR. nStatus != 0
        RETURN "snapshot-failed"
    ENDIF
    cPassword := HBBridgeCredentialReadSecret( @nStatus )
    IF ! HB_ISSTRING( cPassword )
        IF nStatus == 1
            RETURN "redirect"
        ELSEIF nStatus == 4
            RETURN "cancel"
        ENDIF
        RETURN "input-failed"
    ENDIF
    cObserved := HBBridgeCredentialSnapshot( cConfigPath, @nStatus )
    IF ! HB_ISSTRING( cObserved ) .OR. nStatus != 0
        cPassword := NIL
        RETURN "snapshot-failed"
    ENDIF
    cPlan := HBBridgeCredentialPrepareCheckedUpdate( cExpected, cObserved, cBase, cProfile, cPassword, hConfig, @cError )
    cPassword := NIL
    IF ! HB_ISSTRING( cPlan )
        RETURN iif( cError == "CONFIG_CHANGED", "conflict", "prepare-failed" )
    ENDIF
    IF HBBridgeCredentialPublish( cConfigPath, cExpected, cPlan, @nStatus )
        RETURN "publish"
    ENDIF
    IF nStatus == 4
        RETURN "conflict"
    ELSEIF nStatus == 8
        RETURN "published-not-durable"
    ENDIF
RETURN "publication-failed"
#endif
